//
//  SpotifyAPI.swift
//  Mixtape
//
//  Created for Mixtape on 13/08/2026.
//

import Foundation

/// Minimal Spotify Web API client using the Client Credentials flow.
/// Used both to resolve metadata for incoming Spotify links and to search
/// for a matching Spotify link when the shared link is from Apple Music.
actor SpotifyAPI {
    static let shared = SpotifyAPI()

    struct Item: Sendable {
        let title: String
        let artist: String
        let album: String?
        let artworkUrl: String?
        let url: String
    }

    enum SpotifyError: Error, LocalizedError {
        case missingCredentials
        case tokenRequestFailed
        case requestFailed
        case notFound

        var errorDescription: String? {
            switch self {
            case .missingCredentials:
                return "Spotify credentials are missing. Add them to Secrets.swift."
            case .tokenRequestFailed:
                return "Could not authenticate with Spotify."
            case .requestFailed:
                return "The Spotify request failed."
            case .notFound:
                return "Spotify returned no results for this link."
            }
        }
    }

    private var cachedToken: String?
    private var tokenExpiry = Date.distantPast

    // MARK: - Lookup by ID

    func track(id: String) async throws -> Item {
        let data = try await get("https://api.spotify.com/v1/tracks/\(id)")
        let track = try Self.decoder.decode(TrackObject.self, from: data)
        return Item(track: track)
    }

    func album(id: String) async throws -> Item {
        let data = try await get("https://api.spotify.com/v1/albums/\(id)")
        let album = try Self.decoder.decode(AlbumObject.self, from: data)
        return Item(album: album)
    }

    // MARK: - Search

    func searchTrack(title: String, artist: String) async throws -> Item? {
        let data = try await get("https://api.spotify.com/v1/search", queryItems: [
            URLQueryItem(name: "q", value: "track:\(title) artist:\(artist)"),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "5"),
        ])
        let response = try Self.decoder.decode(SearchResponse.self, from: data)
        let items = response.tracks?.items ?? []
        let match = items.first { $0.artists.first?.name.caseInsensitiveCompare(artist) == .orderedSame } ?? items.first
        return match.map(Item.init(track:))
    }

    func searchAlbum(title: String, artist: String) async throws -> Item? {
        let data = try await get("https://api.spotify.com/v1/search", queryItems: [
            URLQueryItem(name: "q", value: "album:\(title) artist:\(artist)"),
            URLQueryItem(name: "type", value: "album"),
            URLQueryItem(name: "limit", value: "5"),
        ])
        let response = try Self.decoder.decode(SearchResponse.self, from: data)
        let items = response.albums?.items ?? []
        let match = items.first { $0.artists?.first?.name.caseInsensitiveCompare(artist) == .orderedSame } ?? items.first
        return match.map(Item.init(album:))
    }

    // MARK: - Requests

    private func get(_ urlString: String, queryItems: [URLQueryItem]? = nil) async throws -> Data {
        var components = URLComponents(string: urlString)
        if let queryItems {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw SpotifyError.requestFailed
        }
        var request = URLRequest(url: url)
        let token = try await accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyError.requestFailed
        }
        if http.statusCode == 404 {
            throw SpotifyError.notFound
        }
        guard (200...299).contains(http.statusCode) else {
            throw SpotifyError.requestFailed
        }
        return data
    }

    /// Fetches (and caches) an app-level access token via the Client Credentials flow.
    private func accessToken() async throws -> String {
        if let token = cachedToken, Date() < tokenExpiry {
            return token
        }
        guard !Secrets.spotifyClientID.isEmpty, !Secrets.spotifyClientSecret.isEmpty else {
            throw SpotifyError.missingCredentials
        }
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw SpotifyError.tokenRequestFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let credentials = Data("\(Secrets.spotifyClientID):\(Secrets.spotifyClientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("grant_type=client_credentials".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SpotifyError.tokenRequestFailed
        }
        let tokenResponse = try Self.decoder.decode(TokenResponse.self, from: data)
        cachedToken = tokenResponse.accessToken
        // Refresh a minute early so a token never expires mid-request
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 60))
        return tokenResponse.accessToken
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    // MARK: - Response Models

    private struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: Int
    }

    fileprivate struct TrackObject: Decodable {
        let name: String
        let artists: [ArtistObject]
        let album: AlbumObject
        let externalUrls: ExternalUrls
    }

    fileprivate struct AlbumObject: Decodable {
        let name: String
        let artists: [ArtistObject]?
        let images: [ImageObject]?
        let externalUrls: ExternalUrls?
    }

    fileprivate struct ArtistObject: Decodable {
        let name: String
    }

    fileprivate struct ImageObject: Decodable {
        let url: String
    }

    fileprivate struct ExternalUrls: Decodable {
        let spotify: String
    }

    private struct SearchResponse: Decodable {
        struct Tracks: Decodable {
            let items: [TrackObject]
        }
        struct Albums: Decodable {
            let items: [AlbumObject]
        }
        let tracks: Tracks?
        let albums: Albums?
    }
}

extension SpotifyAPI.Item {
    fileprivate init(track: SpotifyAPI.TrackObject) {
        self.init(
            title: track.name,
            artist: track.artists.first?.name ?? "Unknown Artist",
            album: track.album.name,
            artworkUrl: track.album.images?.first?.url,
            url: track.externalUrls.spotify
        )
    }

    fileprivate init(album: SpotifyAPI.AlbumObject) {
        self.init(
            title: album.name,
            artist: album.artists?.first?.name ?? "Unknown Artist",
            album: album.name,
            artworkUrl: album.images?.first?.url,
            url: album.externalUrls?.spotify ?? ""
        )
    }
}
