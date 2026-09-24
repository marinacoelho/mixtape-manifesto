const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

// Stored in Secret Manager, never in the client. Set them with:
//   firebase functions:secrets:set SPOTIFY_CLIENT_ID
//   firebase functions:secrets:set SPOTIFY_CLIENT_SECRET
const spotifyClientId = defineSecret("SPOTIFY_CLIENT_ID");
const spotifyClientSecret = defineSecret("SPOTIFY_CLIENT_SECRET");

// Spotify IDs are 22-character base62 strings. Validating them stops a
// caller from smuggling extra path segments into the API URL.
const SPOTIFY_ID_PATTERN = /^[0-9A-Za-z]{22}$/;
const MAX_SEARCH_FIELD_LENGTH = 200;

// App-level Client Credentials token, cached per function instance and
// refreshed a minute early so it never expires mid-request
let cachedToken = null;
let tokenExpiry = 0;

async function accessToken() {
  if (cachedToken && Date.now() < tokenExpiry) {
    return cachedToken;
  }
  const credentials = Buffer.from(
    `${spotifyClientId.value()}:${spotifyClientSecret.value()}`
  ).toString("base64");
  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!response.ok) {
    console.error(`Spotify token request failed: ${response.status}`);
    throw new HttpsError("unavailable", "Could not authenticate with Spotify.");
  }
  const json = await response.json();
  cachedToken = json.access_token;
  tokenExpiry = Date.now() + (json.expires_in - 60) * 1000;
  return cachedToken;
}

async function spotifyGet(path, params) {
  const url = new URL(`https://api.spotify.com/v1/${path}`);
  if (params) {
    url.search = new URLSearchParams(params).toString();
  }
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${await accessToken()}` },
  });
  if (response.status === 401) {
    // Token revoked early; drop it so the next call fetches a fresh one
    cachedToken = null;
  }
  if (response.status === 404) {
    throw new HttpsError("not-found", "Spotify returned no results for this link.");
  }
  if (!response.ok) {
    console.error(`Spotify request to ${path} failed: ${response.status}`);
    throw new HttpsError("unavailable", "The Spotify request failed.");
  }
  return response.json();
}

// MARK: - Response mapping (mirrors the fields the app stores in TrackMetadata)

function itemFromTrack(track) {
  return {
    title: track.name,
    artist: track.artists?.[0]?.name ?? "Unknown Artist",
    album: track.album?.name ?? null,
    artworkUrl: track.album?.images?.[0]?.url ?? null,
    url: track.external_urls.spotify,
  };
}

function itemFromAlbum(album) {
  return {
    title: album.name,
    artist: album.artists?.[0]?.name ?? "Unknown Artist",
    album: album.name,
    artworkUrl: album.images?.[0]?.url ?? null,
    url: album.external_urls?.spotify ?? "",
  };
}

// Prefer a result whose primary artist matches exactly, else the top hit
function bestMatch(items, artist) {
  const wanted = artist.toLowerCase();
  return (
    items.find((item) => item.artists?.[0]?.name?.toLowerCase() === wanted) ??
    items[0] ??
    null
  );
}

// MARK: - Input validation

function requireId(data) {
  if (typeof data.id !== "string" || !SPOTIFY_ID_PATTERN.test(data.id)) {
    throw new HttpsError("invalid-argument", "A valid Spotify ID is required.");
  }
  return data.id;
}

function requireSearchField(data, field) {
  const value = data[field];
  if (
    typeof value !== "string" ||
    value.trim().length === 0 ||
    value.length > MAX_SEARCH_FIELD_LENGTH
  ) {
    throw new HttpsError("invalid-argument", `A valid ${field} is required.`);
  }
  return value;
}

// MARK: - Callable

// Looks up a Spotify track/album by ID, or searches for one by title and
// artist. Only callable from a genuine, signed-in copy of the app: App Check
// rejects requests that don't come from our attested app, and the auth check
// rejects anonymous callers.
exports.spotifyLookup = onCall(
  {
    region: "europe-west2",
    enforceAppCheck: true,
    secrets: [spotifyClientId, spotifyClientSecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to look up songs.");
    }
    const data = request.data ?? {};

    switch (data.action) {
      case "track": {
        const track = await spotifyGet(`tracks/${requireId(data)}`);
        return { item: itemFromTrack(track) };
      }
      case "album": {
        const album = await spotifyGet(`albums/${requireId(data)}`);
        return { item: itemFromAlbum(album) };
      }
      case "searchTrack": {
        const title = requireSearchField(data, "title");
        const artist = requireSearchField(data, "artist");
        const json = await spotifyGet("search", {
          q: `track:${title} artist:${artist}`,
          type: "track",
          limit: "5",
        });
        const match = bestMatch(json.tracks?.items ?? [], artist);
        return { item: match ? itemFromTrack(match) : null };
      }
      case "searchAlbum": {
        const title = requireSearchField(data, "title");
        const artist = requireSearchField(data, "artist");
        const json = await spotifyGet("search", {
          q: `album:${title} artist:${artist}`,
          type: "album",
          limit: "5",
        });
        const match = bestMatch(json.albums?.items ?? [], artist);
        return { item: match ? itemFromAlbum(match) : null };
      }
      default:
        throw new HttpsError("invalid-argument", "Unknown action.");
    }
  }
);
