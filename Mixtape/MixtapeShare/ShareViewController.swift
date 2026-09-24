//
//  ShareViewController.swift
//  MixtapeShare
//
//  Created for Mixtape on 22/07/2026.
//

import UIKit
import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import FirebaseAuth

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        // The extension is its own process, so Firebase needs configuring here
        // too. GoogleService-Info.plist is already a member of this target.
        // App Check must be registered first, mirroring MixtapeApp, or the
        // spotifyLookup function will reject the extension's calls.
        if FirebaseApp.app() == nil {
            #if DEBUG
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
            AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
            #endif
            FirebaseApp.configure()
        }
        // Read the auth session the main app stored in the shared keychain group
        do {
            try Auth.auth().useUserAccessGroup(SharedConfig.keychainAccessGroup)
        } catch {
            print("Failed to use shared keychain access group: \(error)")
        }

        extractSharedURL { [weak self] url in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.presentSwiftUISheet(with: url)
            }
        }
    }
    
    private func extractSharedURL(completion: @escaping (String?) -> Void) {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(nil)
            return
        }
        
        for item in extensionItems {
            if let attachments = item.attachments {
                for provider in attachments {
                    if provider.canLoadObject(ofClass: URL.self) {
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url {
                                completion(url.absoluteString)
                            } else {
                                // Some apps register a public.url representation
                                // that only coerces to a string, so don't give
                                // up until that has been tried too
                                _ = provider.loadObject(ofClass: String.self) { text, _ in
                                    completion(text)
                                }
                            }
                        }
                        return
                    } else if provider.canLoadObject(ofClass: String.self) {
                        _ = provider.loadObject(ofClass: String.self) { text, _ in
                            if let text, text.contains("http") {
                                completion(text)
                            } else {
                                completion(nil)
                            }
                        }
                        return
                    }
                }
            }
        }
        completion(nil)
    }
    
    private func presentSwiftUISheet(with url: String?) {
        let defaultURL = url ?? "https://open.spotify.com/track/1eyzqe2WK00aV5vfcH9bcf"
        let shareView = ShareLauncherSheetView(sharedUrl: defaultURL) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        
        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
