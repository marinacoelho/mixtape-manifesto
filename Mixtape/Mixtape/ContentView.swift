//
//  ContentView.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) var authManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                NavigationStack {
                    ContactListView()
                }
            } else {
                AuthView()
            }
        }
        // Ask for push permission once signed in, and tie this device's
        // FCM token to whichever user is active
        .task(id: authManager.currentUser?.uid) {
            NotificationManager.shared.associate(uid: authManager.currentUser?.uid)
            if authManager.currentUser != nil {
                await NotificationManager.shared.requestAuthorizationAndRegister()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
}
