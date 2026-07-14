import Foundation
@preconcurrency import ARKit
import Combine
import CoreVideo

/// Manages the ARKit session, LiDAR depth capture, and depth frame publishing.
final class ARSessionManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var currentDepthFrame: DepthFrame?
    @Published var isRunning = false
    @Published var sessionError: String?

    /// Raw camera pixel buffer for Vision processing.
    /// Published so ViewModel can subscribe and forward to VisionDetector.
    @Published private(set) var currentPixelBuffer: CVPixelBuffer?

    // MARK: - Private Properties

    /// Exposed so ARCameraView can share the same session.
    let arSession = ARSession()
    private let processingQueue = DispatchQueue(label: "com.sonicvision.depth", qos: .userInitiated)
    private var lastUpdateTime: TimeInterval = 0
    private let minUpdateInterval: TimeInterval = 0.1 // 10 Hz max
    private var supportsLiDAR = false
    private var simulationTimer: Timer?
    private var framePublishCount = 0

    // MARK: - Init

    override init() {
        supportsLiDAR = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        super.init()
        // Delegate is set by ARCameraView.Coordinator (which forwards calls back here).
        // For simulation mode (no ARCameraView), set self as fallback delegate.
        arSession.delegate = self

        if supportsLiDAR {
            print("[ARSession] LiDAR supported")
        } else {
            print("[ARSession] LiDAR NOT supported — simulation mode available")
        }
    }

    deinit {
        simulationTimer?.invalidate()
    }

    // MARK: - Session Management

    func start() {
        guard !isRunning else { return }

        if supportsLiDAR {
            startARSession()
        } else {
            startSimulation()
        }
    }

    func stop() {
        guard isRunning else { return }
        print("[ARSession] Stopping session")

        if supportsLiDAR {
            arSession.pause()
        } else {
            simulationTimer?.invalidate()
            simulationTimer = nil
        }

        isRunning = false
        currentDepthFrame = nil
    }

    // MARK: - AR Session

    private func startARSession() {
        let configuration = ARWorldTrackingConfiguration()

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
            print("[ARSession] sceneDepth enabled")
        }

        configuration.planeDetection = [.horizontal, .vertical]
        configuration.worldAlignment = .gravity

        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        sessionError = nil
        print("[ARSession] AR session started")
    }

    // MARK: - Simulation Fallback

    private func startSimulation() {
        print("[ARSession] Running in simulation mode")
        isRunning = true
        sessionError = nil

        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, self.isRunning else { return }

            let distance = Float.random(in: 0.5...2.5)
            let angle = Float.random(in: -0.5...0.5)
            let frame = DepthFrame(closestDistance: distance, dominantAngle: angle)

            DispatchQueue.main.async {
                self.currentDepthFrame = frame
            }
        }
    }

    // MARK: - Depth Processing

    /// Extracts the closest point and its angular position from a depth buffer.
    /// Analyzes a central region of interest (10% of width/height) for efficiency.
    private func calculateClosestPoint(from depthMap: CVPixelBuffer) -> (distance: Float, angle: Float) {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return (distance: 3.0, angle: 0.0)
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.size

        // Region of interest: central 10%
        let roiWidth = max(width / 10, 1)
        let roiHeight = max(height / 10, 1)
        let startX = (width - roiWidth) / 2
        let startY = (height - roiHeight) / 2

        var minDistance: Float = Float.greatestFiniteMagnitude
        var minX = width / 2

        for y in startY..<(startY + roiHeight) {
            for x in startX..<(startX + roiWidth) {
                let depth = floatBuffer[y * floatsPerRow + x]
                if depth > 0.01 && depth < minDistance && !depth.isNaN {
                    minDistance = depth
                    minX = x
                }
            }
        }

        // Clamp to valid range
        if minDistance == Float.greatestFiniteMagnitude {
            minDistance = 3.0
        }

        // Calculate horizontal angle: pixel offset from center normalized to [-1, 1]
        let centerX = Float(width) / 2.0
        let normalizedOffset = (Float(minX) - centerX) / centerX
        let angle = atan2(normalizedOffset, 1.0)

        return (distance: minDistance, angle: angle)
    }
}

// MARK: - ARSessionDelegate

extension ARSessionManager: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Throttle: max 10 updates/sec
        let now = frame.timestamp
        guard now - lastUpdateTime >= minUpdateInterval else { return }
        lastUpdateTime = now

        // nonisolated(unsafe) suppresses Sendable warnings for CVPixelBuffer
        // which is thread-safe in practice (reference-counted Core Foundation type)
        nonisolated(unsafe) let capturedImage = frame.capturedImage

        guard let sceneDepth = frame.sceneDepth else {
            // Still forward pixel buffer even without depth (Vision needs it)
            DispatchQueue.main.async {
                self.framePublishCount += 1
                self.currentPixelBuffer = capturedImage
                if self.framePublishCount <= 3 {
                    print("[ARSession] Published pixelBuffer #\(self.framePublishCount) (no depth)")
                }
            }
            return
        }

        nonisolated(unsafe) let depthMap = sceneDepth.depthMap

        processingQueue.async { [weak self] in
            guard let self else { return }

            let result = self.calculateClosestPoint(from: depthMap)
            let depthFrame = DepthFrame(
                closestDistance: result.distance,
                dominantAngle: result.angle,
                timestamp: now
            )

            DispatchQueue.main.async {
                self.framePublishCount += 1
                self.currentPixelBuffer = capturedImage
                self.currentDepthFrame = depthFrame
                if self.framePublishCount <= 3 || self.framePublishCount % 50 == 0 {
                    print("[ARSession] Published pixelBuffer #\(self.framePublishCount) + depth \(String(format: "%.2f", depthFrame.closestDistance))m")
                }
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        let arError = error as NSError
        let message: String

        switch arError.code {
        case 100: // ARError.sensorFailed
            message = "Capteur LiDAR indisponible. Vérifiez que rien ne bloque le capteur."
            print("[ARSession] Sensor failed")
        case 102: // ARError.worldTrackingFailed
            message = "Le suivi spatial a échoué. Essayez dans un environnement mieux éclairé."
            print("[ARSession] World tracking failed")
        case 103: // ARError.cameraUnauthorized
            message = "Accès caméra refusé. Activez-le dans Réglages > Confidentialité."
            print("[ARSession] Camera unauthorized")
        default:
            message = "Erreur ARKit : \(error.localizedDescription)"
            print("[ARSession] Error: \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
            self.sessionError = message
            self.isRunning = false
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("[ARSession] Session interrupted")
        DispatchQueue.main.async {
            self.sessionError = "Session interrompue. Revenez dans l'application."
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("[ARSession] Interruption ended — resuming")
        DispatchQueue.main.async {
            self.sessionError = nil
        }
    }
}
