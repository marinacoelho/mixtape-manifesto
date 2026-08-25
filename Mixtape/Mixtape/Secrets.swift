//
//  Secrets.swift
//  Mixtape
//
//  Created for Mixtape on 13/08/2026.
//

import Foundation

/// API credentials for a friends-only build.
///
/// Create an app at https://developer.spotify.com/dashboard and paste its
/// Client ID and Client Secret below. Apple Music lookups use the keyless
/// iTunes Search API, so no Apple credentials are needed.
///
/// Embedding secrets in the binary is acceptable for a private build shared
/// between friends, but do not ship a public release like this.
enum Secrets {
    static let spotifyClientID = "a67cb52d92ad418496b118f985203984"
    static let spotifyClientSecret = "f25153af7f7a4a278a8ce380b4e06359"
}
