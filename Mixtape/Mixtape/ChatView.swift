//
//  ChatView.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI

struct ChatView: View {
    @Environment(AuthManager.self) var authManager
    let contact: UserContact
    @State private var firestoreManager = FirestoreManager()
    @State private var urlInput = ""
    
    var isValidLink: Bool {
        URLValidator.isValidStreamingURL(urlInput)
    }
    
    var detectedService: StreamingService? {
        URLValidator.identifyService(for: urlInput)
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Message History Stream
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(spacing: 20) {
                            if firestoreManager.messages.isEmpty {
                                VStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.05))
                                            .frame(width: 70, height: 70)
                                        Image(systemName: "sparkles.tv")
                                            .font(.system(size: 32))
                                            .foregroundStyle(Color.purple)
                                    }
                                    
                                    Text("The Streaming Wars End Here")
                                        .font(.headline)
                                        .foregroundStyle(.white.opacity(0.9))
                                    
                                    Text("Paste a Spotify or Apple Music link below. Mixtape automatically finds the matching track and renders launch buttons for both platforms!")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                ForEach(firestoreManager.messages) { message in
                                    let isMe = message.senderUid == authManager.currentUser?.uid
                                    HStack {
                                        if isMe { Spacer(minLength: 28) }
                                        MixtapeCardView(message: message, isOutgoing: isMe)
                                        if !isMe { Spacer(minLength: 28) }
                                    }
                                    .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .onChange(of: firestoreManager.messages.count) {
                            if let last = firestoreManager.messages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                // Open at the newest message; the initial count change fires before
                // rows are laid out, so rely on the scroll anchor for first render
                .defaultScrollAnchor(.bottom)
                // Give the message stream more room: collapse the nav bar while
                // scrolling back through history
                .toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)

                // Link-Only Composer
                VStack(spacing: 8) {
                    // Validation Badge
                    if !urlInput.isEmpty {
                        HStack(spacing: 6) {
                            if let service = detectedService {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.green)
                                Text("Valid \(service.rawValue) Link Detected")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.green)
                            } else {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(Color.orange)
                                Text("Please paste a valid Spotify or Apple Music link")
                                    .font(.caption)
                                    .foregroundStyle(Color.orange)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut, value: isValidLink)
                    }
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "link")
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 20)
                            
                            TextField("Paste Spotify or Apple Music URL...", text: $urlInput)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .autocorrectionDisabled(true)
                                .foregroundStyle(.white)
                            
                            if !urlInput.isEmpty {
                                Button(action: { urlInput = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(isValidLink ? Color.green.opacity(0.6) : Color.white.opacity(0.1), lineWidth: isValidLink ? 1.5 : 1)
                        )
                        
                        // Send Trigger (Disabled until regex validation succeeds)
                        Button(role: nil, action: {
                            let urlToSend = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            urlInput = ""
                            Task {
                                guard let me = authManager.currentUser else { return }
                                try? await firestoreManager.sendMessage(url: urlToSend, conversationId: contact.conversationId, senderUid: me.uid)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(isValidLink ? LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 48, height: 48)
                                    .shadow(color: isValidLink ? Color.pink.opacity(0.5) : Color.clear, radius: 8, x: 0, y: 4)
                                
                                if firestoreManager.isSending {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(isValidLink ? Color.white : Color.white.opacity(0.3))
                                }
                            }
                        }
                        .disabled(!isValidLink || firestoreManager.isSending)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.03))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Contact identity lives in the nav bar, inline with the back button
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 30, height: 30)
                        Text(String(contact.contactName.prefix(1)).uppercased())
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    Text(contact.contactName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            // Reclaim the default item margins so longer contact names fit
            .contentMarginsRemoved()
        }
        .task(id: contact.conversationId) {
            await firestoreManager.listenToMessages(for: contact.conversationId)
        }
    }
}
