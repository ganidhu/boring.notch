import AppKit
import SwiftUI

struct NotchHomeView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var musicManager = MusicManager.shared

    let albumArtNamespace: Namespace.ID

    @State private var scrubPosition: Double = 0
    @State private var isScrubbing = false

    private var spotifyReady: Bool {
        musicManager.bundleIdentifier == "com.spotify.client"
    }

    var body: some View {
        ZStack {
            playerBackdrop

            VStack(spacing: 0) {
                topBlackSection
                    .frame(height: 205)

                glassControlsSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: openNotchSize.width, height: openNotchSize.height)
        .clipShape(
            NotchShape(
                topCornerRadius: cornerRadiusInsets.opened.top,
                bottomCornerRadius: cornerRadiusInsets.opened.bottom
            )
        )
        .overlay {
            NotchShape(
                topCornerRadius: cornerRadiusInsets.opened.top,
                bottomCornerRadius: cornerRadiusInsets.opened.bottom
            )
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.42), radius: 12, y: 6)
        .contentShape(Rectangle())
        .horizontalTrackpadSwipe(threshold: 48) { direction in
            guard !isScrubbing else { return }
            switch direction {
            case .left:
                musicManager.nextTrack()
            case .right:
                musicManager.previousTrack()
            }
        }
        .onAppear {
            musicManager.forceUpdate()
            scrubPosition = musicManager.elapsedTime
        }
        .onChange(of: musicManager.elapsedTime) { _, value in
            guard !isScrubbing else { return }
            scrubPosition = value
        }
        .onChange(of: musicManager.songTitle) { _, _ in
            guard !isScrubbing else { return }
            scrubPosition = musicManager.elapsedTime
        }
    }

    private var topBlackSection: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: max(vm.effectiveClosedNotchHeight, 34) + 8)

            HStack(spacing: 14) {
                artwork
                    .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 3) {
                    Text(spotifyReady ? musicManager.songTitle : "Spotify")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(spotifyReady ? musicManager.artistName : "Open Spotify to start playing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ReferenceWaveform(isPlaying: musicManager.isPlaying)
                    .frame(width: 30, height: 22)
            }
            .padding(.horizontal, 22)

            Spacer(minLength: 10)

            TimelineView(.animation(minimumInterval: musicManager.isPlaying ? 0.12 : nil)) { timeline in
                progressRow(date: timeline.date)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 13)
        }
    }

    private var glassControlsSection: some View {
        transportControls
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var playerBackdrop: some View {
        ZStack {
            ReferenceGlassBackdrop()

            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.50),
                    .init(color: .black.opacity(0.90), location: 0.62),
                    .init(color: .black.opacity(0.62), location: 0.76),
                    .init(color: .black.opacity(0.38), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                AppIcon(for: "com.spotify.client")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 25, height: 25)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.42), radius: 3, y: 1)
                    .offset(x: 3, y: 3)
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

        return HStack(spacing: 8) {
            Text(timeString(livePosition))
                .frame(width: 38, alignment: .leading)

            ReferenceScrubber(
                value: isScrubbing ? scrubPosition : livePosition,
                duration: duration,
                isScrubbing: $isScrubbing,
                scrubPosition: $scrubPosition,
                onSeek: musicManager.seek(to:)
            )
            .frame(height: 13)

            Text("-\(timeString(remaining))")
                .frame(width: 44, alignment: .trailing)
        }
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.58))
    }

    private var transportControls: some View {
        HStack(spacing: 0) {
            ReferenceTransportButton(
                systemName: "shuffle",
                size: 17,
                active: musicManager.isShuffled,
                action: musicManager.toggleShuffle
            )

            Spacer()

            ReferenceTransportButton(
                systemName: "backward.fill",
                size: 24,
                action: musicManager.previousTrack
            )

            Spacer()

            ReferenceTransportButton(
                systemName: musicManager.isPlaying ? "pause.fill" : "play.fill",
                size: 28,
                action: musicManager.togglePlay
            )
            .frame(width: 42)

            Spacer()

            ReferenceTransportButton(
                systemName: "forward.fill",
                size: 24,
                action: musicManager.nextTrack
            )

            Spacer()

            ReferenceTransportButton(
                systemName: "laptopcomputer",
                size: 18,
                muted: true,
                action: openSoundSettings
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func openSpotify() {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.spotify.client"
        ) else { return }

        NSWorkspace.shared.openApplication(
            at: appURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    private func openSoundSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Sound-Settings.extension"
        ) else { return }
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

private struct ReferenceScrubber: View {
    let value: Double
    let duration: Double
    @Binding var isScrubbing: Bool
    @Binding var scrubPosition: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let normalized = duration > 0
                ? CGFloat(min(max(value / duration, 0), 1))
                : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 4.5)

                Capsule()
                    .fill(Color.white.opacity(0.96))
                    .frame(
                        width: max(normalized * width, normalized > 0 ? 5 : 0),
                        height: 4.5
                    )
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

private struct ReferenceTransportButton: View {
    let systemName: String
    let size: CGFloat
    var active = false
    var muted = false
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
                        : Color.white.opacity(muted ? 0.58 : 0.97)
                )
                .frame(minWidth: 34, minHeight: 36)
                .scaleEffect(hovering ? 1.06 : 1)
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct ReferenceWaveform: View {
    let isPlaying: Bool

    private let barCount = 7
    private let profile: [Double] = [0.42, 0.72, 0.94, 0.58, 1.0, 0.76, 0.48]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.10)) { timeline in
            HStack(alignment: .center, spacing: 2.2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color(red: 0.95, green: 0.48, blue: 0.57))
                        .frame(
                            width: 2.4,
                            height: barHeight(index: index, date: timeline.date)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func barHeight(index: Int, date: Date) -> CGFloat {
        let shape = profile[index]

        guard isPlaying else {
            return CGFloat(4.5 + (shape * 5.5))
        }

        let time = date.timeIntervalSinceReferenceDate
        let phase = Double(index) * 0.73
        let primary = (sin((time * (2.0 + Double(index) * 0.09)) + phase) + 1) * 0.5
        let secondary = (sin((time * 3.15) + phase * 1.7) + 1) * 0.5
        let energy = 0.30 + ((primary * 0.68 + secondary * 0.32) * 0.70)
        let shapedEnergy = (0.68 + shape * 0.32) * energy

        return CGFloat(4.5 + shapedEnergy * 13.5)
    }
}

private struct ReferenceGlassBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .hudWindow
        nsView.blendingMode = .behindWindow
        nsView.state = .active
    }
}
