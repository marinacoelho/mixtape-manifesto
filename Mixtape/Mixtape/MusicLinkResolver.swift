//
//  MusicLinkResolver.swift
//  Mixtape
//
//  Created for Mixtape on 13/08/2026.
//

import Foundation

/// Resolves a shared Spotify or Apple Music link into full TrackMetadata.
///
/// The flow is: identify the source platform from the URL, call that
/// platform's API to get the title/artist/artwork, then search the other
/// platform for the matching link. If no match is found, the other
/// platform's URL falls back to a search-page link so the recipient can
/// still find the track.
struct MusicLinkResolver {
    enum ResolverError: Error, LocalizedError {
        case unsupportedURL
        case unrecognizedLinkFormat

        var errorDescription: String? {
            switch self {
            case .unsupportedURL:
                return "This link isn't a Spotify or Apple Music link."
            case .unrecognizedLinkFormat:
                return "Couldn't find a track or album ID in this link."
            }
        }
    }

    static func resolve(_ rawUrl: String) async throws -> TrackMetadata {
        let trimmed = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let service = URLValidator.identifyService(for: trimmed),
              let url = URL(string: trimmed) else {
            throw ResolverError.unsupportedURL
        }

        switch service {
        case .spotify:
            return try await resolveFromSpotify(url: url)
        case .appleMusic:
            return try await resolveFromAppleMusic(url: url)
        }
    }

    // MARK: - Spotify → Apple Music

    private static func resolveFromSpotify(url: URL) async throws -> TrackMetadata {
        guard let resource = spotifyResource(in: url) else {
            throw ResolverError.unrecognizedLinkFormat
        }

        // Search Apple Music in the sender's storefront so the resulting
        // link carries catalog IDs that are valid in their country
        let storefront = deviceStorefront()

        let source: SpotifyAPI.Item
        let appleMatch: AppleMusicAPI.Item?
        switch resource.kind {
        case "album":
            source = try await SpotifyAPI.shared.album(id: resource.id)
            appleMatch = try? await AppleMusicAPI.searchAlbum(title: source.title, artist: source.artist, storefront: storefront)
        default:
            source = try await SpotifyAPI.shared.track(id: resource.id)
            appleMatch = try? await AppleMusicAPI.searchTrack(title: source.title, artist: source.artist, storefront: storefront)
        }

        return TrackMetadata(
            title: source.title,
            artist: source.artist,
            album: source.album,
            artworkUrl: source.artworkUrl ?? appleMatch?.artworkUrl,
            spotifyUrl: source.url,
            appleMusicUrl: appleMatch?.url ?? appleMusicSearchUrl(title: source.title, artist: source.artist)
        )
    }

    // MARK: - Apple Music → Spotify

    private static func resolveFromAppleMusic(url: URL) async throws -> TrackMetadata {
        let storefront = appleMusicStorefront(in: url)

        let source: AppleMusicAPI.Item
        let spotifyMatch: SpotifyAPI.Item?
        if let trackId = appleMusicTrackId(in: url) {
            source = try await AppleMusicAPI.lookupTrack(id: trackId, storefront: storefront)
            spotifyMatch = try? await SpotifyAPI.shared.searchTrack(title: source.title, artist: source.artist)
        } else if let albumId = appleMusicAlbumId(in: url) {
            source = try await AppleMusicAPI.lookupAlbum(id: albumId, storefront: storefront)
            spotifyMatch = try? await SpotifyAPI.shared.searchAlbum(title: source.title, artist: source.artist)
        } else {
            throw ResolverError.unrecognizedLinkFormat
        }

        return TrackMetadata(
            title: source.title,
            artist: source.artist,
            album: source.album,
            artworkUrl: source.artworkUrl ?? spotifyMatch?.artworkUrl,
            spotifyUrl: spotifyMatch?.url ?? spotifySearchUrl(title: source.title, artist: source.artist),
            appleMusicUrl: source.url
        )
    }

    // MARK: - URL Parsing

    /// Extracts the resource kind and ID from a Spotify URL,
    /// e.g. https://open.spotify.com/track/1eyzqe2WK00aV5vfcH9bcf?si=abc → ("track", "1eyzqe2WK00aV5vfcH9bcf")
    private static func spotifyResource(in url: URL) -> (kind: String, id: String)? {
        let components = url.pathComponents
        for (index, component) in components.enumerated() {
            if (component == "track" || component == "album"), index + 1 < components.count {
                return (component, components[index + 1])
            }
        }
        return nil
    }

    /// The storefront of the device doing the resolving, e.g. "gb"
    private static func deviceStorefront() -> String {
        (Locale.current.region?.identifier ?? "us").lowercased()
    }

    /// The two-letter storefront that prefixes Apple Music paths, e.g. /gb/album/...
    private static func appleMusicStorefront(in url: URL) -> String {
        let components = url.pathComponents
        if components.count > 1, components[1].count == 2 {
            return components[1]
        }
        return "us"
    }

    /// Track links are either .../album/name/{albumId}?i={trackId} or .../song/name/{trackId}
    private static func appleMusicTrackId(in url: URL) -> String? {
        if let trackId = queryItemValue("i", in: url) {
            return trackId
        }
        let components = url.pathComponents
        if components.contains("song"), let last = components.last, isNumericId(last) {
            return last
        }
        return nil
    }

    private static func appleMusicAlbumId(in url: URL) -> String? {
        let components = url.pathComponents
        guard components.contains("album"), let last = components.last, isNumericId(last) else {
            return nil
        }
        return last
    }

    private static func isNumericId(_ string: String) -> Bool {
        !string.isEmpty && string.allSatisfy(\.isNumber)
    }

    private static func queryItemValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    // MARK: - Search Fallback Links

    private static func spotifySearchUrl(title: String, artist: String) -> String {
        let query = encodedQuery(title: title, artist: artist)
        return "https://open.spotify.com/search/\(query)"
    }

    private static func appleMusicSearchUrl(title: String, artist: String) -> String {
        let query = encodedQuery(title: title, artist: artist)
        return "https://music.apple.com/search?term=\(query)"
    }

    private static func encodedQuery(title: String, artist: String) -> String {
        let query = "\(title) \(artist)"
        return query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
    }
}
