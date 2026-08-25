//
//  AppleMusicAPI.swift
//  Mixtape
//
//  Created for Mixtape on 13/08/2026.
//

import Foundation

/// Client for Apple's iTunes Search & Lookup API.
/// The API is keyless, so resolving and searching Apple Music content
/// needs no credentials at all.
enum AppleMusicAPI {
    struct Item: Sendable {
        let title: String
        let artist: String
        let album: String?
        let artworkUrl: String?
        let url: String
    }

    enum AppleMusicError: Error, LocalizedError {
        case requestFailed
        case notFound

        var errorDescription: String? {
            switch self {
            case .requestFailed:
                return "The Apple Music request failed."
            case .notFound:
                return "Apple Music returned no results for this link."
            }
        }
    }

    // MARK: - Lookup by ID

    static func lookupTrack(id: String, storefront: String) async throws -> Item {
        let results = try await lookup(id: id, storefront: storefront)
        guard let result = results.first(where: { $0.wrapperType == "track" }),
              let item = Item(track: result) else {
            throw AppleMusicError.notFound
        }
        return item
    }

    static func lookupAlbum(id: String, storefront: String) async throws -> Item {
        let results = try await lookup(id: id, storefront: storefront)
        guard let result = results.first(where: { $0.wrapperType == "collection" }),
              let item = Item(album: result) else {
            throw AppleMusicError.notFound
        }
        return item
    }

    // MARK: - Search

    static func searchTrack(title: String, artist: String, storefront: String) async throws -> Item? {
        let results = try await search(term: "\(title) \(artist)", entity: "song", storefront: storefront)
        let match = bestMatch(in: results.filter { $0.wrapperType == "track" }, artist: artist)
        return match.flatMap(Item.init(track:))
    }

    static func searchAlbum(title: String, artist: String, storefront: String) async throws -> Item? {
        let results = try await search(term: "\(title) \(artist)", entity: "album", storefront: storefront)
        let match = bestMatch(in: results.filter { $0.wrapperType == "collection" }, artist: artist)
        return match.flatMap(Item.init(album:))
    }

    /// Prefers the first result whose artist actually matches, since iTunes
    /// term search can rank covers and karaoke versions above the original.
    private static func bestMatch(in results: [LookupResult], artist: String) -> LookupResult? {
        let target = artist.lowercased()
        let artistMatch = results.first { result in
            guard let name = result.artistName?.lowercased() else { return false }
            return name.contains(target) || target.contains(name)
        }
        return artistMatch ?? results.first
    }

    // MARK: - Requests

    private static func lookup(id: String, storefront: String) async throws -> [LookupResult] {
        try await request(path: "lookup", queryItems: [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "country", value: storefront),
        ])
    }

    private static func search(term: String, entity: String, storefront: String) async throws -> [LookupResult] {
        // Without an explicit country the API searches the US storefront, whose
        // catalog IDs (and result URLs) aren't valid in other countries
        try await request(path: "search", queryItems: [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: entity),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "country", value: storefront),
        ])
    }

    private static func request(path: String, queryItems: [URLQueryItem]) async throws -> [LookupResult] {
        var components = URLComponents(string: "https://itunes.apple.com/\(path)")
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw AppleMusicError.requestFailed
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppleMusicError.requestFailed
        }
        return try JSONDecoder().decode(LookupResponse.self, from: data).results
    }

    // MARK: - Response Models

    private struct LookupResponse: Decodable {
        let results: [LookupResult]
    }

    fileprivate struct LookupResult: Decodable {
        let wrapperType: String?
        let trackName: String?
        let collectionName: String?
        let artistName: String?
        let artworkUrl100: String?
        let trackViewUrl: String?
        let collectionViewUrl: String?
    }

    /// The API returns 100x100 thumbnails; the same CDN path serves larger sizes.
    private static func upscaled(_ artworkUrl: String?) -> String? {
        artworkUrl?.replacingOccurrences(of: "100x100", with: "600x600")
    }
}

extension AppleMusicAPI.Item {
    fileprivate init?(track result: AppleMusicAPI.LookupResult) {
        guard let title = result.trackName, let url = result.trackViewUrl else {
            return nil
        }
        self.init(
            title: title,
            artist: result.artistName ?? "Unknown Artist",
            album: result.collectionName,
            artworkUrl: AppleMusicAPI.upscaled(result.artworkUrl100),
            url: url
        )
    }

    fileprivate init?(album result: AppleMusicAPI.LookupResult) {
        guard let title = result.collectionName, let url = result.collectionViewUrl else {
            return nil
        }
        self.init(
            title: title,
            artist: result.artistName ?? "Unknown Artist",
            album: result.collectionName,
            artworkUrl: AppleMusicAPI.upscaled(result.artworkUrl100),
            url: url
        )
    }
}
