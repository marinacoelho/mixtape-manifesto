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
    var incomingRequests: [ContactRequest] = []
    var messages: [Message] = []
    var errorMessage: String? = nil
    var isSending: Bool = false
    
    private var contactsListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    
    // MARK: - Lifecycle Cleanup
    isolated deinit {
        // Safe Pattern: Guarantee cleanup when View is destroyed and object is deallocated
        stopAllListeners()
    }
    
    private func stopAllListeners() {
        // Note: Captured locally since deinit is isolated
    }
    
    func stopListeningContacts() {
        contactsListener?.remove()
        contactsListener = nil
        requestsListener?.remove()
        requestsListener = nil
    }
    
    func stopListeningMessages() {
        messagesListener?.remove()
        messagesListener = nil
    }
    
    // MARK: - Listen to Contacts and Incoming Requests
    func startListeningContacts(for userId: String) {
        stopListeningContacts()
        
        // Active Contacts
        contactsListener = db.collection("contacts")
            .document(userId)
            .collection("user_contacts")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    if let error = error { print("Error listening contacts: \(error)") }
                    return
                }
                self.activeContacts = documents.compactMap { try? $0.data(as: UserContact.self) }
                // Mirror contacts into the App Group so the share extension can list them
                SharedContactsCache.save(self.activeContacts.map {
                    SharedContact(id: $0.contactUid, email: $0.contactEmail, name: $0.contactName, conversationId: $0.conversationId)
                })
            }
        
        // Incoming Requests
        requestsListener = db.collection("contact_requests")
            .whereField("toUid", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    if let error = error { print("Error listening requests: \(error)") }
                    return
                }
                self.incomingRequests = documents.compactMap { try? $0.data(as: ContactRequest.self) }
            }
    }
    
    // MARK: - Listen to Messages (Link-Only Thread)
    func startListeningMessages(for conversationId: String) {
        stopListeningMessages()
        
        messagesListener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    if let error = error { print("Error listening messages: \(error)") }
                    return
                }
                self.messages = documents.compactMap { try? $0.data(as: Message.self) }
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
