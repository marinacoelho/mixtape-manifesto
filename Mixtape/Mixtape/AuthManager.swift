//
//  AuthManager.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
final class AuthManager {
    var currentUser: AppUser? = nil
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    // Safe Firestore reference (no inline initialization before configuration)
    private var db: Firestore {
        if let dbId = FirestoreManager.customDatabaseID, !dbId.isEmpty {
            return Firestore.firestore(database: dbId)
        } else {
            return Firestore.firestore()
        }
    }
    
    init() {
        setupAuthListener()
    }
    
    private func setupAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            Task { @MainActor in
                if let user = user, let email = user.email {
                    self.isAuthenticated = true
                    self.fetchUserDocument(uid: user.uid, email: email)
                } else {
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
            }
        }
    }
    
    private func fetchUserDocument(uid: String, email: String) {
        Task {
            do {
                let doc = try await db.collection("users").document(uid).getDocument()
                if let appUser = try? doc.data(as: AppUser.self) {
                    self.currentUser = appUser
                } else {
                    let formatter = ISO8601DateFormatter()
                    let newUser = AppUser(uid: uid, email: email, createdAt: formatter.string(from: Date()))
                    try db.collection("users").document(uid).setData(from: newUser)
                    self.currentUser = newUser
                }
            } catch {
                print("Error fetching user document: \(error)")
                let formatter = ISO8601DateFormatter()
                self.currentUser = AppUser(uid: uid, email: email, createdAt: formatter.string(from: Date()))
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            if let userEmail = result.user.email {
                fetchUserDocument(uid: result.user.uid, email: userEmail)
            }
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid
            let formatter = ISO8601DateFormatter()
            let newUser = AppUser(uid: uid, email: email, createdAt: formatter.string(from: Date()))
            try db.collection("users").document(uid).setData(from: newUser)
            self.currentUser = newUser
            self.isAuthenticated = true
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isAuthenticated = false
            self.currentUser = nil
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
