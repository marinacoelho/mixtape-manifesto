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
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
}
