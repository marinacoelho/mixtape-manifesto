//
//  ContactListView.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI

struct ContactListView: View {
    @Environment(AuthManager.self) var authManager
    @State private var firestoreManager = FirestoreManager()
    @State private var showAddContactModal = false
    @State private var selectedContact: UserContact? = nil
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mixtape")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .pink, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                        if let user = authManager.currentUser {
                            Text(user.displayName)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(role: nil, action: {
                            showAddContactModal = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(Circle())
                                .shadow(color: Color.pink.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        
                        Menu {
                            Button(role: .destructive, action: {
                                authManager.signOut()
                            }) {
                                Label("Sign Out", systemImage: "arrow.right.square")
                            }
                        } label: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(Color.white.opacity(0.02))
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Incoming Requests Section
                        if !firestoreManager.incomingRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "person.2.wave.2.fill")
                                        .foregroundStyle(Color.orange)
                                    Text("CONTACT REQUESTS")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.white.opacity(0.7))
                                    Spacer()
                                    Text("\(firestoreManager.incomingRequests.count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundStyle(Color.orange)
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 4)
                                
                                ForEach(firestoreManager.incomingRequests) { request in
                                    RequestCardView(request: request, firestoreManager: firestoreManager, currentUser: authManager.currentUser)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }
                        
                        // Active Contacts Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ACTIVE CONTACTS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.white.opacity(0.5))
                                .padding(.horizontal, 24)
                            
                            if !firestoreManager.hasLoadedContacts {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .tint(Color.pink)
                                        .controlSize(.large)
                                    Text("Loading contacts...")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                            } else if firestoreManager.activeContacts.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 40))
                                        .foregroundStyle(Color.white.opacity(0.2))
                                    
                                    Text("No music contacts yet")
                                        .font(.headline)
                                        .foregroundStyle(.white.opacity(0.8))
                                    
                                    Text("Tap '+' above to add a contact by email and start sharing Spotify & Apple Music streaming links!")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.5))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(20)
                                .padding(.horizontal, 20)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(firestoreManager.activeContacts) { contact in
                                        NavigationLink(destination: ChatView(contact: contact)) {
                                            ContactCardRow(contact: contact)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .sheet(isPresented: $showAddContactModal) {
            AddContactModalView(firestoreManager: firestoreManager)
        }
        // SAFE PATTERN: Tie listener lifecycle to identity using .task(id:)
        .task(id: authManager.currentUser?.uid) {
            if let uid = authManager.currentUser?.uid {
                firestoreManager.startListeningContacts(for: uid)
            } else {
                firestoreManager.stopListeningContacts()
            }
        }
    }
}

// MARK: - Subcomponents
struct RequestCardView: View {
    let request: ContactRequest
    let firestoreManager: FirestoreManager
    let currentUser: AppUser?
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.fill.questionmark")
                    .foregroundStyle(Color.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Wants to swap mixtapes")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .tint(.white)
            } else {
                HStack(spacing: 8) {
                    Button(action: {
                        Task {
                            guard let me = currentUser else { return }
                            isProcessing = true
                            try? await firestoreManager.acceptRequest(request, currentUser: me)
                            isProcessing = false
                        }
                    }) {
                        Text("Accept")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.pink)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: {
                        Task {
                            isProcessing = true
                            try? await firestoreManager.rejectRequest(request)
                            isProcessing = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .foregroundStyle(.white.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ContactCardRow: View {
    let contact: UserContact
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.pink.opacity(0.7), Color.purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                
                Text(String(contact.contactName.prefix(1)).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.contactName)
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Ready for links")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
