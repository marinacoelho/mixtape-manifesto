//
//  Models.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import Foundation

// MARK: - User Model
struct AppUser: Codable, Identifiable, Hashable, Sendable {
    var id: String { uid }
    let uid: String
    let email: String
    let createdAt: String
    let displayName: String
}

// MARK: - Contact Request Model
struct ContactRequest: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let fromUid: String
    let fromEmail: String
    let fromName: String
    let toUid: String
    let status: String // "pending", "accepted", "rejected"

    var isPending: Bool { status == "pending" }
}

// MARK: - User Contact Model
struct UserContact: Codable, Identifiable, Hashable, Sendable {
    var id: String { contactUid }
    let contactUid: String
    let contactEmail: String
    let contactName: String
    let conversationId: String
    
    static func generateConversationId(uid1: String, uid2: String) -> String {
        let minUid = min(uid1, uid2)
        let maxUid = max(uid1, uid2)
        return "\(minUid)_\(maxUid)"
    }
}

// MARK: - Track Metadata
struct TrackMetadata: Codable, Hashable, Sendable {
    let title: String
    let artist: String
    let album: String?
    let artworkUrl: String?
    let spotifyUrl: String
    let appleMusicUrl: String
}

// MARK: - Message Model
struct Message: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let senderUid: String
    let timestamp: String
    let originalUrl: String
    let metadata: TrackMetadata
}
