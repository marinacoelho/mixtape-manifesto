//
//  MixtapeApp.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck

@main
struct MixtapeApp: App {
    init() {
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
//        FirebaseApp.configure()
    }

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
