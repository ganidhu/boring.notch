import AppKit
import Defaults
import SwiftUI

@MainActor
struct ContentView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared

    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering = false
    @State private var gestureProgress: CGFloat = 0
    @State private var haptics = false

    @Namespace private var albumArtNamespace

    @Default(.openNotchOnHover) private var openOnHover
    @Default(.minimumHoverDuration) private var minimumHoverDuration
    @Default(.enableHaptics) private var enableHaptics
    @Default(.hudReplacement) private var hudReplacement
    @Default(.inlineHUD) private var inlineHUD

    private let animationSpring = Animation.interactiveSpring(
        response: 0.34,
        dampingFraction: 0.84,
        blendDuration: 0
    )

    var body: some View {
        ZStack(alignment: .top) {
            if vm.notchState == .open {
                expandedSurface
            } else {
                closedSurface
            }
        }
        .frame(
            maxWidth: windowSize.width,
            maxHeight: windowSize.height,
            alignment: .top
        )
        .preferredColorScheme(.dark)
        .environmentObject(vm)
        .sensoryFeedback(.alignment, trigger: haptics)
        .onDisappear {
            hoverTask?.cancel()
        }
    }

    private var expandedSurface: some View {
        NotchHomeView(albumArtNamespace: albumArtNamespace)
            .frame(width: openNotchSize.width, height: openNotchSize.height)
            .contentShape(Rectangle())
            .onHover(perform: handleHover)
            .transition(
                .scale(scale: 0.94, anchor: .top)
                    .combined(with: .opacity)
            )
            .animation(animationSpring, value: vm.notchState)
            .contextMenu {
                Button("Settings") {
                    DispatchQueue.main.async {
                        SettingsWindowController.shared.showWindow()
                    }
                }
                .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            }
    }

    @ViewBuilder
    private var closedSurface: some View {
        if shouldShowBatteryStatus {
            batterySurface
                .contentShape(Rectangle())
                .onHover(perform: handleHover)
        } else if shouldShowSystemHUD {
            systemHUDSurface
                .contentShape(Rectangle())
                .onHover(perform: handleHover)
        } else if shouldShowMusicActivity {
            ClosedMusicLiveActivity(albumArtNamespace: albumArtNamespace)
                .environmentObject(vm)
                .contentShape(Rectangle())
                .onHover(perform: handleHover)
                .onTapGesture(perform: openNotch)
        } else {
            closedNotchOnly
                .contentShape(Rectangle())
                .onHover(perform: handleHover)
                .onTapGesture(perform: openNotch)
        }
    }

    private var closedNotchOnly: some View {
        Color.black
            .frame(
                width: vm.closedNotchSize.width,
                height: vm.effectiveClosedNotchHeight
            )
            .clipShape(
                NotchShape(
                    topCornerRadius: cornerRadiusInsets.closed.top,
                    bottomCornerRadius: cornerRadiusInsets.closed.bottom
                )
            )
    }

    private var shouldShowMusicActivity: Bool {
        coordinator.musicLiveActivityEnabled
            && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && !vm.hideOnClosed
    }

    private var shouldShowBatteryStatus: Bool {
        coordinator.expandingView.show
            && coordinator.expandingView.type == .battery
            && Defaults[.showPowerStatusNotifications]
    }

    private var shouldShowSystemHUD: Bool {
        coordinator.sneakPeek.show
            && coordinator.sneakPeek.type != .music
            && coordinator.sneakPeek.type != .battery
            && hudReplacement
    }

    private var batterySurface: some View {
        HStack(spacing: 10) {
            Text(batteryModel.statusText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Color.black
                .frame(width: vm.closedNotchSize.width)

            BoringBatteryView(
                batteryWidth: 30,
                isCharging: batteryModel.isCharging,
                isInLowPowerMode: batteryModel.isInLowPowerMode,
                isPluggedIn: batteryModel.isPluggedIn,
                levelBattery: batteryModel.levelBattery,
                isForNotification: true
            )
        }
        .padding(.horizontal, 12)
        .frame(height: vm.effectiveClosedNotchHeight)
        .background(.black)
        .clipShape(
            NotchShape(
                topCornerRadius: cornerRadiusInsets.closed.top,
                bottomCornerRadius: cornerRadiusInsets.closed.bottom
            )
        )
    }

    private var systemHUDSurface: some View {
        InlineHUD(
            type: $coordinator.sneakPeek.type,
            value: $coordinator.sneakPeek.value,
            icon: $coordinator.sneakPeek.icon,
            hoverAnimation: $isHovering,
            gestureProgress: $gestureProgress
        )
        .frame(minWidth: vm.closedNotchSize.width + (inlineHUD ? 110 : 70))
        .frame(height: vm.effectiveClosedNotchHeight)
        .padding(.horizontal, 8)
        .background(.black)
        .clipShape(
            NotchShape(
                topCornerRadius: cornerRadiusInsets.closed.top,
                bottomCornerRadius: cornerRadiusInsets.closed.bottom
            )
        )
    }

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()

        if hovering {
            isHovering = true

            if vm.notchState == .closed && enableHaptics {
                haptics.toggle()
            }

            guard vm.notchState == .closed, openOnHover else { return }

            hoverTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(minimumHoverDuration))
                guard !Task.isCancelled, isHovering, vm.notchState == .closed else { return }
                openNotch()
            }
        } else {
            isHovering = false

            hoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(130))
                guard !Task.isCancelled, !isHovering else { return }
                if vm.notchState == .open && !vm.isBatteryPopoverActive {
                    closeNotch()
                }
            }
        }
    }

    private func openNotch() {
        withAnimation(animationSpring) {
            vm.open()
        }
    }

    private func closeNotch() {
        withAnimation(animationSpring) {
            vm.close()
        }
    }
}

private struct ClosedMusicLiveActivity: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var musicManager = MusicManager.shared

    let albumArtNamespace: Namespace.ID

    private var totalWidth: CGFloat {
        vm.closedNotchSize.width + 104
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .scaledToFill()
                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                .frame(width: 25, height: 25)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.leading, 11)

            Spacer(minLength: 0)

            ReferenceWaveform(isPlaying: musicManager.isPlaying)
                .frame(width: 28, height: 20)
                .padding(.trailing, 12)
        }
        .frame(width: totalWidth, height: vm.effectiveClosedNotchHeight)
        .background(.black)
        .clipShape(
            NotchShape(
                topCornerRadius: cornerRadiusInsets.closed.top,
                bottomCornerRadius: cornerRadiusInsets.closed.bottom
            )
        )
        .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
    }
}

#Preview {
    let vm = BoringViewModel()
    return ContentView()
        .environmentObject(vm)
        .frame(width: windowSize.width, height: windowSize.height)
}
