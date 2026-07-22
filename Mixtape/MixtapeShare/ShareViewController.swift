//
//  ShareViewController.swift
//  MixtapeShare
//
//  Created for Mixtape on 22/07/2026.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
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
                    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, error in
                            if let url = data as? URL {
                                completion(url.absoluteString)
                                return
                            } else if let urlString = data as? String {
                                completion(urlString)
                                return
                            }
                        }
                        return
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, error in
                            if let text = data as? String, text.contains("http") {
                                completion(text)
                                return
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
