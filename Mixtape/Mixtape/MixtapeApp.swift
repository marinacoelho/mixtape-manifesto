//
//  MixtapeApp.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI
import FirebaseCore

@main
struct MixtapeApp: App {
    // CRITICAL: Safely configure Firebase before any managers or views are instantiated in App hierarchy
    @State private var authManager = {
        FirebaseApp.configure()
        return AuthManager()
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .preferredColorScheme(.dark)
        }
    }
}
