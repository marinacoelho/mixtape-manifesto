//
//  MixtapeApp.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck

// Receives the APNs callbacks that SwiftUI has no equivalent for
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // FirebaseApp.configure() has already run in MixtapeApp's state initializer
        NotificationManager.shared.configure()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationManager.shared.handleAPNSToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error)")
    }
}

@main
struct MixtapeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
