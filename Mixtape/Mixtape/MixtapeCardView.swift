//
//  MixtapeCardView.swift
//  Mixtape
//
//  Created for Mixtape on 22/07/2026.
//

import SwiftUI

struct MixtapeCardView: View {
    // Artwork URLs are immutable CDN assets, so give them a generous cache of
    // their own rather than sharing the shared session's much smaller one.
    private static let artworkSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024,
                                          diskCapacity: 128 * 1024 * 1024)
        return URLSession(configuration: configuration)
    }()

    let message: Message
    let isOutgoing: Bool
    @Environment(\.openURL) var openURL
    
    var body: some View {
        VStack(spacing: 0) {
            // Album Artwork & Header
            ZStack(alignment: .bottomLeading) {
                if let urlString = message.metadata.artworkUrl, let url = URL(string: urlString) {
                    // .returnCacheDataElseLoad: artwork never changes for a
                    // given URL, so a cache hit should skip the network entirely
                    AsyncImage(request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Color.white.opacity(0.1)
                                ProgressView().tint(.white)
                            }
                            .frame(height: 220)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .clipped()
                        case .failure:
                            FallbackArtworkView()
                        @unknown default:
                            FallbackArtworkView()
                        }
                    }
                    .asyncImageURLSession(Self.artworkSession)
                } else {
                    FallbackArtworkView()
                }
                
                // Dark vignette overlay for text contrast
                LinearGradient(
                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.3), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 120)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.metadata.title)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "music.mic")
                            .font(.caption2)
                            .foregroundStyle(Color.pink)
                        Text(message.metadata.artist)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                .padding(16)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            // Dual Action Buttons (Single-tap launch for both Spotify & Apple Music)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    // Open in Spotify Button
                    Button(action: {
                        if let url = URL(string: message.metadata.spotifyUrl) {
                            openURL(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle.fill")
                                .font(.headline)
                            Text("Spotify")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.11, green: 0.73, blue: 0.33)) // Vibrant Spotify Green #1DB954
                        .foregroundStyle(.white)
                        .cornerRadius(14)
                        .shadow(color: Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                    
                    // Open in Apple Music Button
                    Button(action: {
                        if let url = URL(string: message.metadata.appleMusicUrl) {
                            openURL(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "applelogo")
                                .font(.subheadline)
                            Text("Apple Music")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.98, green: 0.14, blue: 0.24)) // Vibrant Apple Music Pink/Red #FA243C
                        .foregroundStyle(.white)
                        .cornerRadius(14)
                        .shadow(color: Color(red: 0.98, green: 0.14, blue: 0.24).opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                }
                
                // Timestamp and platform-match Tag
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(Color.purple)
                        Text("Matched on Spotify & Apple Music")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    if let date = ISO8601DateFormatter().date(from: message.timestamp) {
                        Text(date.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .offset(y: -12)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(isOutgoing ? Color.purple.opacity(0.15) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(isOutgoing ? Color.purple.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

struct FallbackArtworkView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.6), Color.pink.opacity(0.6), Color.orange.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "opticaldisc.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(height: 220)
    }
}
