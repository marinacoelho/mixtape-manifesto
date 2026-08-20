//
//  SharedContactsCache.swift
//  Mixtape
//
//  Created for Mixtape on 29/07/2026.
//
//  Compiled into both the main app and the MixtapeShare extension.
//  The main app writes its contact list here whenever Firestore updates;
//  the share extension reads it to populate its recipient list.
//

import Foundation

// MARK: - Shared Contact Snapshot
struct SharedContact: Codable, Identifiable, Hashable, Sendable {
    let id: String // contact uid
    let email: String
    // Optional so caches written before display names existed still decode
    let name: String?
    let conversationId: String

    /// Name to show in the share sheet, falling back to the email's local part
    var displayLabel: String {
        if let name, !name.isEmpty { return name }
        return String(email.split(separator: "@").first ?? "Friend")
    }
}

// MARK: - App Group Cache
enum SharedContactsCache {
    static let appGroupID = "group.io.brokenhands.apps.MixtapeApp"
    private static let contactsKey = "sharedContacts"

    static func save(_ contacts: [SharedContact]) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(contacts) else { return }
        defaults.set(data, forKey: contactsKey)
    }

    static func load() -> [SharedContact] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: contactsKey),
              let contacts = try? JSONDecoder().decode([SharedContact].self, from: data) else {
            return []
        }
        return contacts
    }

    static func clear() {
        UserDefaults(suiteName: appGroupID)?.removeObject(forKey: contactsKey)
    }
}
