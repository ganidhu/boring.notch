import Foundation
import Cocoa
import ApplicationServices
import AsyncXPCConnection

final class XPCHelperClient: NSObject {
    nonisolated static let shared = XPCHelperClient()
    
    private let serviceName = "theboringteam.boringnotch.BoringNotchXPCHelper"
    
    private var remoteService: RemoteXPCService<BoringNotchXPCHelperProtocol>?
    private var connection: NSXPCConnection?
    private var lastKnownAuthorization: Bool?
    private var monitoringTask: Task<Void, Never>?
    
    deinit {
        connection?.invalidate()
        stopMonitoringAccessibilityAuthorization()
    }
    
    // MARK: - Connection Management
    
    @MainActor
    private func ensureRemoteService() -> RemoteXPCService<BoringNotchXPCHelperProtocol> {
        if let existing = remoteService {
            return existing
        }
        
        let conn = NSXPCConnection(serviceName: serviceName)
        
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
                self?.remoteService = nil
            }
        }
        
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
                self?.remoteService = nil
            }
        }
        
        conn.resume()
        
        let service = RemoteXPCService<BoringNotchXPCHelperProtocol>(
            connection: conn,
            remoteInterface: BoringNotchXPCHelperProtocol.self
        )
        
        connection = conn
        remoteService = service
        return service
    }
    
    @MainActor
    private func notifyAuthorizationChange(_ granted: Bool) {
        guard lastKnownAuthorization != granted else { return }
        lastKnownAuthorization = granted
        NotificationCenter.default.post(
            name: .accessibilityAuthorizationChanged,
            object: nil,
            userInfo: ["granted": granted]
        )
    }

    // MARK: - Monitoring

    nonisolated func startMonitoringAccessibilityAuthorization(every interval: TimeInterval = 1.0) {
        stopMonitoringAccessibilityAuthorization()
        monitoringTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                _ = await self.isAccessibilityAuthorized()
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    break
                }
            }
        }
    }

    nonisolated func stopMonitoringAccessibilityAuthorization() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    var isMonitoring: Bool {
        monitoringTask != nil
    }
    
    // MARK: - Accessibility
    // Accessibility trust belongs to the process installing the event tap.
    // The event tap lives in the main app, so checking the XPC helper here
    // reports the wrong permission state after the user enables the app.
    
    nonisolated func requestAccessibilityAuthorization() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    nonisolated func isAccessibilityAuthorized() async -> Bool {
        let result = AXIsProcessTrusted()
        await MainActor.run {
            notifyAuthorizationChange(result)
        }
        return result
    }
    
    nonisolated func ensureAccessibilityAuthorization(promptIfNeeded: Bool) async -> Bool {
        if AXIsProcessTrusted() {
            await MainActor.run {
                notifyAuthorizationChange(true)
            }
            return true
        }

        if promptIfNeeded {
            requestAccessibilityAuthorization()
        }

        // System Settings updates TCC asynchronously. Keep checking long enough
        // for the user to enable the app instead of immediately flipping the
        // HUD replacement toggle back off.
        let attempts = promptIfNeeded ? 120 : 1
        for _ in 0..<attempts {
            let trusted = AXIsProcessTrusted()
            await MainActor.run {
                notifyAuthorizationChange(trusted)
            }
            if trusted {
                return true
            }

            if attempts > 1 {
                try? await Task.sleep(for: .milliseconds(500))
            }
        }

        return false
    }
    
    // MARK: - Keyboard Brightness
    
    nonisolated func isKeyboardBrightnessAvailable() async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.isKeyboardBrightnessAvailable { available in
                    continuation.resume(returning: available)
                }
            }
        } catch {
            return false
        }
    }
    
    nonisolated func currentKeyboardBrightness() async -> Float? {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            let result: NSNumber? = try await service.withContinuation { service, continuation in
                service.currentKeyboardBrightness { value in
                    continuation.resume(returning: value)
                }
            }
            return result?.floatValue
        } catch {
            return nil
        }
    }
    
    nonisolated func setKeyboardBrightness(_ value: Float) async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.setKeyboardBrightness(value) { success in
                    continuation.resume(returning: success)
                }
            }
        } catch {
            return false
        }
    }
    
    // MARK: - Screen Brightness
    
    nonisolated func isScreenBrightnessAvailable() async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.isScreenBrightnessAvailable { available in
                    continuation.resume(returning: available)
                }
            }
        } catch {
            return false
        }
    }
    
    nonisolated func currentScreenBrightness() async -> Float? {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            let result: NSNumber? = try await service.withContinuation { service, continuation in
                service.currentScreenBrightness { value in
                    continuation.resume(returning: value)
                }
            }
            return result?.floatValue
        } catch {
            return nil
        }
    }
    
    nonisolated func setScreenBrightness(_ value: Float) async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.setScreenBrightness(value) { success in
                    continuation.resume(returning: success)
                }
            }
        } catch {
            return false
        }
    }
}

extension Notification.Name {
    static let accessibilityAuthorizationChanged = Notification.Name("accessibilityAuthorizationChanged")
}
