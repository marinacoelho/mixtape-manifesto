//
//  ShareLauncherSheetView.swift
//  MixtapeShare
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI

struct ShareLauncherSheetView: View {
    let sharedUrl: String
    let onDismiss: () -> Void

    @State private var contacts: [SharedContact] = []
    @State private var selectedContact: SharedContact? = nil
    @State private var isSending = false
    @State private var sendSuccess = false
    
    var isSpotify: Bool { sharedUrl.contains("spotify.com") }
    
    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.11).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                        Image(systemName: "opticaldisc.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share via Mixtape")
                            .font(.title3)
                            .fontWeight(.heavy)
                            .foregroundStyle(.white)
                        Text("Pick a contact to send link")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                // Shared Link Card
                HStack(spacing: 14) {
                    Circle()
                        .fill(isSpotify ? Color(red: 0.11, green: 0.73, blue: 0.33) : Color(red: 0.98, green: 0.14, blue: 0.24))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: isSpotify ? "play.circle.fill" : "applelogo")
                                .foregroundStyle(.white)
                                .font(.headline)
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isSpotify ? "Spotify Streaming Track" : "Apple Music Streaming Track")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text(sharedUrl)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                
                // Contacts List
                VStack(alignment: .leading, spacing: 12) {
                    Text("SELECT RECIPIENT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                    
                    if contacts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2.slash")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.4))
                            Text("No contacts yet")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Open Mixtape and add a contact to share music.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                    }

                    VStack(spacing: 10) {
                        ForEach(contacts) { contact in
                            Button(action: {
                                selectedContact = contact
                            }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .top, endPoint: .bottom))
                                        .frame(width: 38, height: 38)
                                        .overlay(
                                            Text(String(contact.email.prefix(1)).uppercased())
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        )
                                    
                                    Text(contact.email)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                    
                                    if selectedContact?.id == contact.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.pink)
                                            .font(.title3)
                                    } else {
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                            .frame(width: 22, height: 22)
                                    }
                                }
                                .padding(12)
                                .background(selectedContact?.id == contact.id ? Color.pink.opacity(0.15) : Color.white.opacity(0.04))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(selectedContact?.id == contact.id ? Color.pink.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Spacer()
                
                // Dispatch Button
                Button(action: {
                    guard selectedContact != nil else { return }
                    isSending = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        isSending = false
                        sendSuccess = true
                        try? await Task.sleep(for: .seconds(0.8))
                        onDismiss()
                    }
                }) {
                    HStack {
                        if isSending {
                            ProgressView().tint(.white)
                            Text("Gemini Resolving & Sending...")
                                .font(.headline)
                                .fontWeight(.bold)
                        } else if sendSuccess {
                            Image(systemName: "checkmark")
                            Text("Sent!")
                                .font(.headline)
                                .fontWeight(.bold)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Dispatch Mixtape")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedContact != nil ? LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(16)
                    .shadow(color: selectedContact != nil ? Color.pink.opacity(0.4) : Color.clear, radius: 10, x: 0, y: 5)
                }
                .disabled(selectedContact == nil || isSending)
            }
            .padding(24)
        }
        .onAppear {
            contacts = SharedContactsCache.load()
        }
    }
}
