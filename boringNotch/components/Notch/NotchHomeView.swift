//
//  NotchHomeView.swift
//  boringNotch
//
//  Spotify-first hover player, styled from the supplied reference.
//

import AppKit
import SwiftUI

// MARK: - Main View

struct NotchHomeView: View {
    @EnvironmentObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        SpotifyReferencePlayerView(albumArtNamespace: albumArtNamespace)
            .environmentObject(vm)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }
}

// MARK: - Reference Spotify Player

private struct SpotifyReferencePlayerView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var musicManager = MusicManager.shared

    let albumArtNamespace: Namespace.ID

    @State private var scrubPosition: Double = 0
    @State private var isScrubbing = false

    private var spotifyReady: Bool {
        musicManager.bundleIdentifier == "com.spotify.client"
    }

    var body: some View {
        VStack(spacing: 0) {
            topRow
                .padding(.horizontal, 16)

            Spacer(minLength: 24)

            TimelineView(.animation(minimumInterval: musicManager.isPlaying ? 0.12 : nil)) { timeline in
                progressRow(date: timeline.date)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 26)

            transportControls
                .padding(.horizontal, 34)

            Spacer(minLength: 24)
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            musicManager.forceUpdate()
            scrubPosition = musicManager.elapsedTime
        }
        .onChange(of: musicManager.elapsedTime) { _, newValue in
            guard !isScrubbing else { return }
            scrubPosition = newValue
        }
        .onChange(of: musicManager.songTitle) { _, _ in
            guard !isScrubbing else { return }
            scrubPosition = musicManager.elapsedTime
        }
    }

    private var topRow: some View {
        HStack(spacing: 26) {
            artwork
                .frame(width: 134, height: 134)

            VStack(alignment: .leading, spacing: 5) {
                Text(spotifyReady ? musicManager.songTitle : "Spotify")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(spotifyReady ? musicManager.artistName : "Open Spotify to start playing")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ReferenceWaveform(isPlaying: musicManager.isPlaying)
                .frame(width: 46, height: 34)
                .padding(.trailing, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var artwork: some View {
        Button(action: openSpotify) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if spotifyReady {
                        Image(nsImage: musicManager.albumArt)
                            .resizable()
                            .scaledToFill()
                            .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                    } else {
                        AppIcon(for: "com.spotify.client")
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 134, height: 134)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                AppIcon(for: "com.spotify.client")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
                    .offset(x: 6, y: 6)
            }
        }
        .buttonStyle(.plain)
    }

    private func progressRow(date: Date) -> some View {
        let livePosition = isScrubbing
            ? scrubPosition
            : musicManager.estimatedPlaybackPosition(at: date)
        let duration = max(musicManager.songDuration, 0)
        let remaining = max(duration - livePosition, 0)

        return HStack(spacing: 14) {
            Text(timeString(livePosition))
                .frame(width: 64, alignment: .leading)

            ReferenceScrubber(
                value: isScrubbing ? scrubPosition : livePosition,
                duration: duration,
                isScrubbing: $isScrubbing,
                scrubPosition: $scrubPosition,
                onSeek: { newPosition in
                    musicManager.seek(to: newPosition)
                }
            )
            .frame(height: 16)

            Text("-\(timeString(remaining))")
                .frame(width: 64, alignment: .trailing)
        }
        .font(.system(size: 21, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.56))
    }

    private var transportControls: some View {
        HStack(alignment: .center, spacing: 0) {
            ReferenceTransportButton(
                systemName: "shuffle",
                size: 28,
                active: musicManager.isShuffled,
                action: { musicManager.toggleShuffle() }
            )

            Spacer()

            ReferenceTransportButton(
                systemName: "backward.fill",
                size: 42,
                action: { musicManager.previousTrack() }
            )

            Spacer()

            ReferenceTransportButton(
                systemName: musicManager.isPlaying ? "pause.fill" : "play.fill",
                size: 52,
                action: { musicManager.togglePlay() }
            )
            .frame(width: 62)

            Spacer()

            ReferenceTransportButton(
                systemName: "forward.fill",
                size: 42,
                action: { musicManager.nextTrack() }
            )

            Spacer()

            ReferenceTransportButton(
                systemName: "laptopcomputer",
                size: 29,
                muted: true,
                action: openSoundSettings
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func openSpotify() {
        let bundleID = "com.spotify.client"
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    }

    private func openSoundSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let rounded = Int(seconds.rounded(.down))
        let hours = rounded / 3600
        let minutes = (rounded % 3600) / 60
        let secs = rounded % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Progress

private struct ReferenceScrubber: View {
    let value: Double
    let duration: Double
    @Binding var isScrubbing: Bool
    @Binding var scrubPosition: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let normalized = duration > 0 ? CGFloat(min(max(value / duration, 0), 1)) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 10)

                Capsule()
                    .fill(Color.white.opacity(0.96))
                    .frame(width: max(normalized * width, normalized > 0 ? 10 : 0), height: 10)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard duration > 0 else { return }
                        isScrubbing = true
                        let percent = min(max(gesture.location.x / width, 0), 1)
                        scrubPosition = duration * Double(percent)
                    }
                    .onEnded { _ in
                        guard duration > 0 else {
                            isScrubbing = false
                            return
                        }
                        onSeek(scrubPosition)
                        isScrubbing = false
                    }
            )
        }
    }
}

// MARK: - Transport Controls

private struct ReferenceTransportButton: View {
    let systemName: String
    let size: CGFloat
    var active: Bool = false
    var muted: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(
                    active
                        ? Color(red: 0.96, green: 0.49, blue: 0.58)
                        : Color.white.opacity(muted ? 0.56 : 0.97)
                )
                .frame(minWidth: 44, minHeight: 52)
                .scaleEffect(hovering ? 1.06 : 1)
                .opacity(hovering ? 1 : 0.96)
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Visualizer

private struct ReferenceWaveform: View {
    let isPlaying: Bool

    private let barCount = 7

    var body: some View {
        TimelineView(.animation(minimumInterval: isPlaying ? 0.12 : nil)) { timeline in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let wave = abs(sin(time * (2.4 + Double(index) * 0.13) + Double(index) * 0.8))
                    let activeHeight = CGFloat(10 + (wave * 22))
                    let height: CGFloat = isPlaying ? activeHeight : CGFloat(12 + ((index * 5) % 9))

                    Capsule()
                        .fill(Color(red: 0.95, green: 0.48, blue: 0.57))
                        .frame(width: 4, height: height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
