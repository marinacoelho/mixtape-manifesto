//
//  AddContactModalView.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI

struct AddContactModalView: View {
    @Environment(AuthManager.self) var authManager
    @Environment(\.dismiss) var dismiss
    let firestoreManager: FirestoreManager
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var statusMessage: String? = nil
    @State private var isError = false
    
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.08, blue: 0.14).ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Text("Add Contact")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Enter your friend's email address to start sharing Spotify and Apple Music streaming links.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("friend@example.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled(true)
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    
                    if let message = statusMessage {
                        HStack {
                            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(isError ? Color.red : Color.green)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(isError ? Color.red : Color.green)
                        }
                    }
                }
                
                Button(action: {
                    Task {
                        guard let me = authManager.currentUser else { return }
                        isLoading = true
                        statusMessage = nil
                        do {
                            let _ = try await firestoreManager.sendContactRequest(fromUser: me, targetEmail: email)
                            isError = false
                            statusMessage = "Contact request sent to \(email)!"
                            email = ""
                            try? await Task.sleep(for: .seconds(1.5))
                            dismiss()
                        } catch {
                            isError = true
                            statusMessage = error.localizedDescription
                        }
                        isLoading = false
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Send Invitation")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Color.pink, Color.purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(14)
                    .shadow(color: Color.pink.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .disabled(isLoading || email.isEmpty)
                .opacity(email.isEmpty ? 0.6 : 1.0)
                
                Spacer()
            }
            .padding(24)
        }
    }
}
