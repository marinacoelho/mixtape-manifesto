//
//  FirestoreManager.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
final class FirestoreManager {
    static var customDatabaseID: String? = SharedConfig.firestoreDatabaseID
    private var db: Firestore {
        if let dbId = FirestoreManager.customDatabaseID, !dbId.isEmpty {
            return Firestore.firestore(database: dbId)
        } else {
            return Firestore.firestore()
        }
    }
    
    var activeContacts: [UserContact] = []
    /// False until the first contacts snapshot arrives, so views can show a
    /// loading state instead of a premature "no contacts" empty state
    var hasLoadedContacts: Bool = false
    var incomingRequests: [ContactRequest] = []
    var messages: [Message] = []
    var errorMessage: String? = nil
    var isSending: Bool = false
    
    /// Clears contact state when the signed-in user goes away, so a subsequent
    /// sign-in never briefly shows the previous account's contacts
    func clearContacts() {
        activeContacts = []
        incomingRequests = []
        hasLoadedContacts = false
    }
    
    // MARK: - Listen to Contacts and Incoming Requests
    // Each of these consumes a Firestore snapshot AsyncSequence and runs until
    // the calling task is cancelled. Cancellation tears down the underlying
    // listener for us, so there is no registration to hold or remove by hand.
    
    func listenToContacts(for userId: String) async {
        hasLoadedContacts = false
        
        let contacts = db.collection("contacts")
            .document(userId)
            .collection("user_contacts")
        
        do {
            for try await snapshot in contacts.snapshots {
                hasLoadedContacts = true
                activeContacts = snapshot.documents.compactMap { try? $0.data(as: UserContact.self) }
                // Mirror contacts into the App Group so the share extension can list them
                SharedContactsCache.save(activeContacts.map {
                    SharedContact(id: $0.contactUid, email: $0.contactEmail, name: $0.contactName, conversationId: $0.conversationId)
                })
            }
        } catch {
            // A listener error is terminal, so the stream is done: stop showing
            // the loading state and surface why the list is not updating
            hasLoadedContacts = true
            errorMessage = error.localizedDescription
        }
    }
    
    func listenToIncomingRequests(for userId: String) async {
        let requests = db.collection("contact_requests")
            .whereField("toUid", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
        
        do {
            for try await snapshot in requests.snapshots {
                incomingRequests = snapshot.documents.compactMap { try? $0.data(as: ContactRequest.self) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Listen to Messages (Link-Only Thread)
    func listenToMessages(for conversationId: String) async {
        let messagesQuery = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
        
        do {
            for try await snapshot in messagesQuery.snapshots {
                messages = snapshot.documents.compactMap { try? $0.data(as: Message.self) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Contact Actions
    func sendContactRequest(fromUser: AppUser, targetEmail: String) async throws -> Bool {
        let cleanEmail = targetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Find user by email (Limit query size to 1 as mandated by security rules)
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: cleanEmail)
            .limit(to: 1)
            .getDocuments()
        
        guard let targetDoc = snapshot.documents.first, let targetUser = try? targetDoc.data(as: AppUser.self) else {
            throw NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No Mixtape user found with email \(cleanEmail)."])
        }
        
        if targetUser.uid == fromUser.uid {
            throw NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "You cannot add yourself as a contact."])
        }
        
        let requestId = "REQ_\(UUID().uuidString.prefix(8))"
        let request = ContactRequest(
            id: requestId,
            fromUid: fromUser.uid,
            fromEmail: fromUser.email,
            fromName: fromUser.displayName,
            toUid: targetUser.uid,
            status: "pending"
        )
        
        try db.collection("contact_requests").document(requestId).setData(from: request)
        return true
    }
    
    func acceptRequest(_ request: ContactRequest, currentUser: AppUser) async throws {
        // Update request status
        try await db.collection("contact_requests").document(request.id).updateData([
            "status": "accepted"
        ])
        
        let conversationId = UserContact.generateConversationId(uid1: request.fromUid, uid2: currentUser.uid)
        
        // Create reciprocal contacts
        let contactForMe = UserContact(
            contactUid: request.fromUid,
            contactEmail: request.fromEmail,
            contactName: request.fromName,
            conversationId: conversationId
        )
        let contactForThem = UserContact(
            contactUid: currentUser.uid,
            contactEmail: currentUser.email,
            contactName: currentUser.displayName,
            conversationId: conversationId
        )
        
        try db.collection("contacts").document(currentUser.uid).collection("user_contacts").document(request.fromUid).setData(from: contactForMe)
        try db.collection("contacts").document(request.fromUid).collection("user_contacts").document(currentUser.uid).setData(from: contactForThem)
    }
    
    func rejectRequest(_ request: ContactRequest) async throws {
        try await db.collection("contact_requests").document(request.id).updateData([
            "status": "rejected"
        ])
    }
    
    // MARK: - Send Link Message
    func sendMessage(url: String, conversationId: String, senderUid: String) async throws {
        isSending = true
        defer { isSending = false }
        
        // Resolve metadata via the source platform's API, then search the other platform for the matching link
        let metadata = try await MusicLinkResolver.resolve(url)
        
        let msgId = "MSG_\(UUID().uuidString.prefix(8))"
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        
        let message = Message(
            id: msgId,
            senderUid: senderUid,
            timestamp: timestamp,
            originalUrl: url,
            metadata: metadata
        )
        
        try db.collection("conversations").document(conversationId).collection("messages").document(msgId).setData(from: message)
    }
}
