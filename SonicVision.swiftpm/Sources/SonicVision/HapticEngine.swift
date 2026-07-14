import Foundation
import CoreHaptics

/// Manages CoreHaptics engine lifecycle and pattern playback.
/// Transforms depth proximity data into distinct haptic feedback patterns.
final class HapticEngine: ObservableObject {

    // MARK: - Published State

    @Published var isAvailable = false

    // MARK: - Private Properties

    private var engine: CHHapticEngine?
    private var engineNeedsStart = true
    private var lastTriggerTime: TimeInterval = 0
    private let minTriggerInterval: TimeInterval = 0.05 // 50ms anti-spam

    // MARK: - Init

    init() {
        isAvailable = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if !isAvailable {
            print("[HapticEngine] Haptics not supported on this device")
        }
    }

    deinit {
        engine?.stop(completionHandler: { _ in })
    }

    // MARK: - Lifecycle

    func prepare() {
        guard isAvailable else {
            print("[HapticEngine] Skipping — haptics not supported")
            return
        }

        do {
            engine = try CHHapticEngine()
        } catch {
            print("[HapticEngine] Failed to create engine: \(error.localizedDescription)")
            isAvailable = false
            return
        }

        engine?.stoppedHandler = { [weak self] reason in
            print("[HapticEngine] Engine stopped: \(reason.rawValue)")
            self?.engineNeedsStart = true
        }

        engine?.resetHandler = { [weak self] in
            print("[HapticEngine] Engine reset — restarting")
            self?.restartEngine()
        }

        restartEngine()
    }

    func stop() {
        engine?.stop(completionHandler: { _ in })
        engine = nil
        engineNeedsStart = true
        print("[HapticEngine] Stopped")
    }

    // MARK: - Playback

    /// Plays a haptic pattern with the given user-controlled intensity multiplier.
    /// Called by ViewModel: `play(pattern: .proximity(intensity:), intensity:)`
    func play(pattern: HapticPattern, intensity: Double = 1.0) {
        guard isAvailable, engine != nil else { return }

        // Anti-spam throttle
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTriggerTime >= minTriggerInterval else { return }
        lastTriggerTime = now

        // Restart engine if needed
        if engineNeedsStart {
            restartEngine()
            guard !engineNeedsStart else { return }
        }

        // Scale events by user intensity
        let events = pattern.events().map { event -> CHHapticEvent in
            let scaledParams = event.eventParameters.map { param -> CHHapticEventParameter in
                if param.parameterID == .hapticIntensity {
                    return CHHapticEventParameter(
                        parameterID: .hapticIntensity,
                        value: Float(Double(param.value) * intensity)
                    )
                }
                return param
            }
            return CHHapticEvent(
                eventType: event.type,
                parameters: scaledParams,
                relativeTime: event.relativeTime,
                duration: event.duration
            )
        }

        do {
            let hapticPattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: hapticPattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticEngine] Playback failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Engine Management

    private func restartEngine() {
        do {
            try engine?.start()
            engineNeedsStart = false
            print("[HapticEngine] Engine started")
        } catch {
            print("[HapticEngine] Failed to start engine: \(error.localizedDescription)")
            engineNeedsStart = true
        }
    }
}
