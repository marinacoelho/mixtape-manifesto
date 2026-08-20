//
//  Models.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import Foundation

/// Falls back to the email's local part for records saved before display names existed
func displayNameFallback(_ name: String?, email: String) -> String {
    if let name, !name.isEmpty { return name }
    return String(email.split(separator: "@").first ?? "Someone")
}

// MARK: - User Model
struct AppUser: Codable, Identifiable, Hashable, Sendable {
    var id: String { uid }
    let uid: String
    let email: String
    let createdAt: String
    // Optional because accounts created before display names existed have no value stored
    let displayName: String?

    var name: String { displayNameFallback(displayName, email: email) }
}

// MARK: - Contact Request Model
struct ContactRequest: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let fromUid: String
    let fromEmail: String
    let fromName: String?
    let toUid: String
    let status: String // "pending", "accepted", "rejected"

    var isPending: Bool { status == "pending" }
    var senderName: String { displayNameFallback(fromName, email: fromEmail) }
}

// MARK: - User Contact Model
struct UserContact: Codable, Identifiable, Hashable, Sendable {
    var id: String { contactUid }
    let contactUid: String
    let contactEmail: String
    let contactName: String?
    let conversationId: String

    var name: String { displayNameFallback(contactName, email: contactEmail) }
    
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
