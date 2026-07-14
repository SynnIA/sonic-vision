import Foundation
import AVFoundation

/// Generates spatialized 3D audio pings based on obstacle distance and angle.
/// Uses programmatically generated sine waves — no external audio files needed.
final class SpatialAudioEngine: ObservableObject {

    // MARK: - Published State

    @Published var isReady = false

    // MARK: - Audio Graph

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var environmentNode: AVAudioEnvironmentNode?

    // MARK: - Audio Format

    private let sampleRate: Double = 44100

    // MARK: - Pre-generated Buffer Cache

    private var bufferCache: [Int: AVAudioPCMBuffer] = [:]
    private let cachedFrequencies: [Int] = [400, 800, 1200]

    // MARK: - Throttle

    private var lastPingTime: TimeInterval = 0
    private let minPingInterval: TimeInterval = 0.15 // 150ms

    // MARK: - Init

    init() {
        print("[SpatialAudio] Initialized (deferred setup)")
    }

    deinit {
        playerNode?.stop()
        audioEngine?.stop()
    }

    // MARK: - Lifecycle

    func prepare() {
        // Configure audio session first
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("[SpatialAudio] Audio session setup failed: \(error.localizedDescription)")
            return
        }

        // Build audio graph
        setupAudioGraph()

        // Start engine
        guard let audioEngine else {
            print("[SpatialAudio] Audio engine not available")
            return
        }

        do {
            try audioEngine.start()
            playerNode?.play()
            isReady = true
            print("[SpatialAudio] Engine started")
        } catch {
            print("[SpatialAudio] Engine start failed: \(error.localizedDescription)")
            isReady = false
        }
    }

    func stop() {
        playerNode?.stop()
        audioEngine?.stop()

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[SpatialAudio] Failed to deactivate audio session: \(error.localizedDescription)")
        }

        isReady = false
        print("[SpatialAudio] Stopped")
    }

    // MARK: - Setup

    private func setupAudioGraph() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let environment = AVAudioEnvironmentNode()

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else {
            print("[SpatialAudio] Failed to create audio format")
            return
        }

        engine.attach(player)
        engine.attach(environment)

        engine.connect(player, to: environment, format: format)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)

        // Spatial environment settings — tuned for impressive 3D demo
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
        environment.reverbBlend = 0.3
        environment.distanceAttenuationParameters.maximumDistance = 10.0
        environment.distanceAttenuationParameters.referenceDistance = 0.5
        environment.distanceAttenuationParameters.rolloffFactor = 2.0
        environment.renderingAlgorithm = .HRTFHQ

        self.audioEngine = engine
        self.playerNode = player
        self.environmentNode = environment

        // Pre-generate cached buffers
        for freq in cachedFrequencies {
            bufferCache[freq] = generatePingBuffer(frequency: Float(freq), format: format)
        }

        print("[SpatialAudio] Audio graph configured, \(cachedFrequencies.count) buffers cached")
    }

    // MARK: - Spatial Playback

    /// Called by ViewModel with obstacle distance (meters) and horizontal angle (radians).
    func playProximityTone(distance: Float, angle: Float) {
        guard isReady, let audioEngine, audioEngine.isRunning, let playerNode else { return }

        // Throttle pings
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPingTime >= minPingInterval else { return }
        lastPingTime = now

        // Update 3D position — amplified spatial spread for perceptible 3D
        let clampedDistance = min(distance, 5.0)
        let spatialScale: Float = 2.0 // Exaggerate positioning for clear L/R separation
        let position = AVAudio3DPoint(
            x: sin(angle) * clampedDistance * spatialScale,
            y: 0,
            z: -cos(angle) * clampedDistance * spatialScale
        )
        playerNode.position = position

        // Select frequency based on distance
        let frequency: Int
        if distance < 0.5 {
            frequency = 1200
        } else if distance <= 1.5 {
            frequency = 800
        } else {
            frequency = 400
        }

        // Use cached buffer
        guard let buffer = bufferCache[frequency] else { return }
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    // MARK: - Sine Wave Generation

    /// Generates a short sine wave ping with fade-in/out envelope to prevent clicks.
    private func generatePingBuffer(frequency: Float, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration: Double = 0.1
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("[SpatialAudio] Failed to create PCM buffer for \(frequency) Hz")
            return nil
        }
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        let fadeFrames = Int(Double(frameCount) * 0.1) // 10% fade in/out

        for i in 0..<Int(frameCount) {
            let sample = sin(2.0 * .pi * Float(frequency) * Float(i) / Float(sampleRate))

            let envelope: Float
            if i < fadeFrames {
                envelope = Float(i) / Float(fadeFrames)
            } else if i > Int(frameCount) - fadeFrames {
                envelope = Float(Int(frameCount) - i) / Float(fadeFrames)
            } else {
                envelope = 1.0
            }

            channelData[i] = sample * 0.3 * envelope
        }

        return buffer
    }
}
