//
//  URLValidator.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import Foundation

enum StreamingService: String, CaseIterable, Sendable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
}

struct URLValidator: Sendable {
    // Spotify Pattern: ^https?:\/\/(open|play)\.spotify\.com\/(track|album)\/[a-zA-Z0-9]+.*$
    private static let spotifyPattern = "^https?:\\/\\/(open|play)\\.spotify\\.com\\/(track|album)\\/[a-zA-Z0-9]+.*$"
    
    // Apple Music Pattern: ^https?:\/\/music\.apple\.com\/[a-zA-Z]{2}\/(album|song)\/.*$
    private static let appleMusicPattern = "^https?:\\/\\/music\\.apple\\.com\\/[a-zA-Z]{2}\\/(album|song)\\/.*$"
    
    static func isValidStreamingURL(_ urlString: String) -> Bool {
        return identifyService(for: urlString) != nil
    }
    
    static func identifyService(for urlString: String) -> StreamingService? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if matches(pattern: spotifyPattern, in: trimmed) {
            return .spotify
        } else if matches(pattern: appleMusicPattern, in: trimmed) {
            return .appleMusic
        }
        return nil
    }
    
    private static func matches(pattern: String, in string: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }
}
