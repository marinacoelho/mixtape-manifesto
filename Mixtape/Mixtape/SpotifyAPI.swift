//
//  SpotifyAPI.swift
//  Mixtape
//
//  Created for Mixtape on 13/08/2026.
//

import Foundation
import FirebaseFunctions

/// Spotify lookups, proxied through the `spotifyLookup` Cloud Function so the
/// client secret never ships in the app. The function is protected by App
/// Check and requires a signed-in user.
/// Used both to resolve metadata for incoming Spotify links and to search
/// for a matching Spotify link when the shared link is from Apple Music.
actor SpotifyAPI {
    static let shared = SpotifyAPI()

    struct Item: Codable, Sendable {
        let title: String
        let artist: String
        let album: String?
        let artworkUrl: String?
        let url: String
    }

    enum SpotifyError: Error, LocalizedError {
        case unauthorized
        case requestFailed
        case notFound

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Couldn't verify this app with the server. Try signing in again."
            case .requestFailed:
                return "The Spotify request failed."
            case .notFound:
                return "Spotify returned no results for this link."
            }
        }
    }

    private lazy var lookup = Functions.functions(region: "europe-west2")
        .httpsCallable("spotifyLookup", requestAs: LookupRequest.self, responseAs: LookupResponse.self)

    // MARK: - Lookup by ID

    func track(id: String) async throws -> Item {
        guard let item = try await call(LookupRequest(action: "track", id: id)) else {
            throw SpotifyError.notFound
        }
        return item
    }

    func album(id: String) async throws -> Item {
        guard let item = try await call(LookupRequest(action: "album", id: id)) else {
            throw SpotifyError.notFound
        }
        return item
    }

    // MARK: - Search

    func searchTrack(title: String, artist: String) async throws -> Item? {
        try await call(LookupRequest(action: "searchTrack", title: title, artist: artist))
    }

    func searchAlbum(title: String, artist: String) async throws -> Item? {
        try await call(LookupRequest(action: "searchAlbum", title: title, artist: artist))
    }

    // MARK: - Requests

    private func call(_ request: LookupRequest) async throws -> Item? {
        do {
            return try await lookup.call(request).item
        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            switch FunctionsErrorCode(rawValue: error.code) {
            case .notFound:
                throw SpotifyError.notFound
            case .unauthenticated, .permissionDenied:
                throw SpotifyError.unauthorized
            default:
                throw SpotifyError.requestFailed
            }
        }
    }

    private struct LookupRequest: Encodable, Sendable {
        let action: String
        var id: String?
        var title: String?
        var artist: String?
    }

    private struct LookupResponse: Decodable, Sendable {
        let item: Item?
    }
}
