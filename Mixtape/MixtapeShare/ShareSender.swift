//
//  ShareSender.swift
//  MixtapeShare
//
//  Created for Mixtape on 20/08/2026.
//
//  Resolves the shared link and writes the message to Firestore as the
//  signed-in user. Mirrors FirestoreManager.sendMessage in the main app.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum ShareSender {
    enum ShareSendError: Error, LocalizedError {
        case notSignedIn

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Open Mixtape and sign in before sharing."
            }
        }
    }

    static func send(url: String, to contact: SharedContact) async throws {
        guard let senderUid = Auth.auth().currentUser?.uid else {
            throw ShareSendError.notSignedIn
        }

        let metadata = try await MusicLinkResolver.resolve(url)

        let msgId = "MSG_\(UUID().uuidString.prefix(8))"
        let message = Message(
            id: msgId,
            senderUid: senderUid,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            originalUrl: url,
            metadata: metadata
        )

        // Await the server acknowledgement: the extension process can be
        // killed right after dismissal, so a queued-but-unsent write is lost.
        // The Codable setData(from:) overload is synchronous and returns before
        // the write lands, so encode by hand and use the async setData(_:).
        let db = Firestore.firestore(database: SharedConfig.firestoreDatabaseID)
        let encoded = try Firestore.Encoder().encode(message)
        try await db.collection("conversations")
            .document(contact.conversationId)
            .collection("messages")
            .document(msgId)
            .setData(encoded)
    }
}
