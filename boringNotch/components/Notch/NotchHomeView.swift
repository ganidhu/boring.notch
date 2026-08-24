import AppKit
import SwiftUI

struct NotchHomeView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var musicManager = MusicManager.shared

    let albumArtNamespace: Namespace.ID

    @State private var scrubPosition: Double = 0
    @State private var isScrubbing = false
    @State private var swipeBlocked = false

    private var spotifyReady: Bool {
        musicManager.bundleIdentifier == "com.spotify.client"
    }

    var body: some View {
        VStack(spacing: 0) {
            topBlackSection
                .frame(height: 205)
                .background(.black)

            glassControlsSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .simultaneousGesture(swipeGesture)
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

            HStack(spacing: 18) {
                artwork
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 3) {
                    Text(spotifyReady ? musicManager.songTitle : "Spotify")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(spotifyReady ? musicManager.artistName : "Open Spotify to start playing")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ReferenceWaveform(isPlaying: musicManager.isPlaying)
                    .frame(width: 34, height: 28)
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 10)

            TimelineView(.animation(minimumInterval: musicManager.isPlaying ? 0.12 : nil)) { timeline in
                progressRow(date: timeline.date)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 13)
        }
    }

    private var glassControlsSection: some View {
        ZStack {
            ReferenceGlassBackdrop()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.075))
                    .frame(height: 1)

                transportControls
                    .padding(.horizontal, 28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                AppIcon(for: "com.spotify.client")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 31, height: 31)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.42), radius: 4, y: 2)
                    .offset(x: 4, y: 4)
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

        return HStack(spacing: 11) {
            Text(timeString(livePosition))
                .frame(width: 43, alignment: .leading)

            ReferenceScrubber(
                value: isScrubbing ? scrubPosition : livePosition,
                duration: duration,
                isScrubbing: $isScrubbing,
                scrubPosition: $scrubPosition,
                onSeek: musicManager.seek(to:)
            )
            .frame(height: 13)

            Text("-\(timeString(remaining))")
                .frame(width: 49, alignment: .trailing)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.58))
    }

    private var transportControls: some View {
        HStack(spacing: 0) {
            ReferenceTransportButton(
                systemName: "shuffle",
                size: 21,
                active: musicManager.isShuffled,
                action: musicManager.toggleShuffle
            )

            Spacer()

            ReferenceTransportButton(
                systemName: "backward.fill",
                size: 31,
                action: musicManager.previousTrack
            )

            Spacer()

            ReferenceTransportButton(
                systemName: musicManager.isPlaying ? "pause.fill" : "play.fill",
                size: 36,
                action: musicManager.togglePlay
            )
            .frame(width: 48)

            Spacer()

            ReferenceTransportButton(
                systemName: "forward.fill",
                size: 31,
                action: musicManager.nextTrack
            )

            Spacer()

            ReferenceTransportButton(
                systemName: "laptopcomputer",
                size: 22,
                muted: true,
                action: openSoundSettings
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { _ in
                if isScrubbing {
                    swipeBlocked = true
                }
            }
            .onEnded { gesture in
                defer { swipeBlocked = false }

                guard !swipeBlocked else { return }

                let horizontal = gesture.translation.width
                let vertical = gesture.translation.height
                guard abs(horizontal) > 58,
                      abs(horizontal) > abs(vertical) * 1.35
                else { return }

                if horizontal < 0 {
                    musicManager.nextTrack()
                } else {
                    musicManager.previousTrack()
                }
            }
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
                    .frame(height: 6)

                Capsule()
                    .fill(Color.white.opacity(0.96))
                    .frame(
                        width: max(normalized * width, normalized > 0 ? 6 : 0),
                        height: 6
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
                .frame(minWidth: 36, minHeight: 42)
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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { timeline in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color(red: 0.95, green: 0.48, blue: 0.57))
                        .frame(width: 3, height: barHeight(index: index, date: timeline.date))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func barHeight(index: Int, date: Date) -> CGFloat {
        guard isPlaying else {
            return CGFloat(7 + ((index * 4) % 8))
        }

        let time = date.timeIntervalSinceReferenceDate
        let speed = 2.4 + (Double(index) * 0.13)
        let phase = Double(index) * 0.8
        let wave = abs(sin((time * speed) + phase))
        return CGFloat(7 + (wave * 17))
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
