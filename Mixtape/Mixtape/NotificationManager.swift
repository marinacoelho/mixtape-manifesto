//
//  NotificationManager.swift
//  Mixtape
//
//  Created for Mixtape on 20/08/2026.
//
//  Owns push-notification permission, FCM token registration, and
//  persisting the token to the user's Firestore document so the
//  Cloud Function can address this device.
//

import SwiftUI
import UserNotifications
import FirebaseFirestore
import FirebaseMessaging

@MainActor
@Observable
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    /// Conversation the user tapped a notification for; navigation can pick this up to deep-link
    var pendingConversationId: String? = nil

    private var latestFCMToken: String? = nil
    private var associatedUid: String? = nil

    // Safe Firestore reference (no inline initialization before configuration)
    private var db: Firestore {
        if let dbId = FirestoreManager.customDatabaseID, !dbId.isEmpty {
            return Firestore.firestore(database: dbId)
        } else {
            return Firestore.firestore()
        }
    }

    /// Call once at launch, after FirebaseApp.configure()
    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    /// Ask the user for permission and register with APNs. Safe to call repeatedly —
    /// the system only prompts once and re-registration is a no-op.
    func requestAuthorizationAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("Notification authorization failed: \(error)")
        }
    }

    /// Tie the current FCM token to the signed-in user (pass nil on sign-out)
    func associate(uid: String?) {
        associatedUid = uid
        saveTokenIfPossible()
    }

    /// Remove the token from the user's document so a signed-out device stops receiving pushes
    func clearToken(for uid: String) {
        db.collection("users").document(uid).updateData(["fcmToken": FieldValue.delete()]) { error in
            if let error { print("Failed to clear FCM token: \(error)") }
        }
    }

    /// Forward the APNs device token to FCM (called from the app delegate)
    func handleAPNSToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    private func saveTokenIfPossible() {
        guard let uid = associatedUid, let token = latestFCMToken else { return }
        db.collection("users").document(uid).setData(["fcmToken": token], merge: true) { error in
            if let error { print("Failed to save FCM token: \(error)") }
        }
    }
}

// MARK: - MessagingDelegate
extension NotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Printed so the token can be copied for test sends from the Firebase console
        print("FCM token: \(fcmToken ?? "nil")")
        Task { @MainActor in
            self.latestFCMToken = fcmToken
            self.saveTokenIfPossible()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    // Show banners even while the app is in the foreground.
    // Main-actor isolated (inherited from the class): the delegate's completion
    // must run on the main thread, or UIKit aborts during the app's
    // foreground-transition snapshot work when a backgrounded notification is tapped.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let conversationId = userInfo["conversationId"] as? String {
            pendingConversationId = conversationId
        }
    }
}
