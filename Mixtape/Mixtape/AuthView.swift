//
//  AuthView.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI
import FirebaseCore

struct AuthView: View {
    @Environment(AuthManager.self) var authManager
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Rich Dark Aesthetic Gradients
            Color(red: 0.07, green: 0.07, blue: 0.1).ignoresSafeArea()
            
            // Dynamic abstract glowing background orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.35), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 250
                    )
                )
                .frame(width: 450, height: 450)
                .offset(x: pulseAnimation ? -80 : 80, y: pulseAnimation ? -150 : -80)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: pulseAnimation)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.pink.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 300
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: pulseAnimation ? 100 : -100, y: pulseAnimation ? 180 : 100)
                .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: pulseAnimation)
            
            VStack(spacing: 28) {
                Spacer()
                
                // App Brand
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LinearGradient(colors: [Color.orange, Color.pink, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.pink.opacity(0.4), radius: 15, x: 0, y: 8)
                        
                        Image(systemName: "opticaldisc.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(pulseAnimation ? 360 : 0))
                            .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: pulseAnimation)
                    }
                    
                    Text("Mixtape")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("The AI peacekeeper for the streaming wars.")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Auth Glass Card
                VStack(spacing: 20) {
                    Text(isSignUp ? "Create your account" : "Welcome back")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 20)
                            TextField("Email address", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled(true)
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(14)
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 20)
                            SecureField("Password", text: $password)
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(14)
                    }
                    
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: {
                        Task {
                            do {
                                if isSignUp {
                                    try await authManager.signUp(email: email, password: password)
                                } else {
                                    try await authManager.signIn(email: email, password: password)
                                }
                            } catch { }
                        }
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
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
                        .shadow(color: Color.purple.opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                    .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                
                // Toggle Mode Button
                Button(action: {
                    withAnimation(.spring()) {
                        isSignUp.toggle()
                        authManager.errorMessage = nil
                    }
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.pink)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            pulseAnimation = true
        }
    }
}

#Preview {
    // AuthManager relies on a configured Firebase instance, so configure it
    // once before building the preview's environment.
    if FirebaseApp.app() == nil {
        FirebaseApp.configure()
    }
    return AuthView()
        .environment(AuthManager())
        .preferredColorScheme(.dark)
}
