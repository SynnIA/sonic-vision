import SwiftUI
import Combine
import AVFoundation

@MainActor
final class SonicViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isActive = false
    @Published var hapticIntensity: Double = 0.7
    @Published var statusText = "Point at objects to explore"
    @Published var detectedObjects: [DetectedObject] = []
    @Published var closestDistance: Float = 3.0
    @Published var showPermissionAlert = false

    // MARK: - Services
    let arSessionManager = ARSessionManager()
    let hapticEngine = HapticEngine()
    let spatialAudioEngine = SpatialAudioEngine()
    let visionDetector = VisionDetector()

    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    private var pixelBufferCount = 0

    init() {
        setupBindings()
        print("[SonicVM] ViewModel initialized, bindings active")
    }

    // MARK: - Bindings

    private func setupBindings() {
        // Depth frames -> haptic + spatial audio
        arSessionManager.$currentDepthFrame
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                self?.processDepthFrame(frame)
            }
            .store(in: &cancellables)

        // Pixel buffers -> VisionDetector
        arSessionManager.$currentPixelBuffer
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pixelBuffer in
                guard let self else { return }
                self.pixelBufferCount += 1
                if self.pixelBufferCount <= 3 || self.pixelBufferCount % 20 == 0 {
                    print("[SonicVM] Forwarding pixelBuffer #\(self.pixelBufferCount) to VisionDetector")
                }
                self.visionDetector.processFrame(pixelBuffer)
            }
            .store(in: &cancellables)

        // Vision results -> published detectedObjects + status update
        visionDetector.$detectedObjects
            .receive(on: DispatchQueue.main)
            .sink { [weak self] objects in
                guard let self else { return }
                self.detectedObjects = objects
                if !objects.isEmpty && self.isActive {
                    let primary = objects[0]
                    self.statusText = "\(primary.label.capitalized) detected \(String(format: "%.1f", primary.distance))m"
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Permissions

    func checkPermissions() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraStatus {
        case .authorized:
            print("[SonicVM] Camera permission: authorized")
        case .notDetermined:
            print("[SonicVM] Camera permission: requesting")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        print("[SonicVM] Camera permission: granted")
                    } else {
                        print("[SonicVM] Camera permission: denied")
                        self?.statusText = "Camera access required"
                        self?.showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            print("[SonicVM] Camera permission: denied/restricted")
            statusText = "Camera access required"
            showPermissionAlert = true
        @unknown default:
            break
        }
    }

    // MARK: - Session Control

    func startSession() {
        guard !isActive else { return }
        print("[SonicVM] Starting session")
        isActive = true
        statusText = "Scanning..."

        arSessionManager.start()
        hapticEngine.prepare()
        spatialAudioEngine.prepare()
        visionDetector.start()
    }

    func stopSession() {
        guard isActive else { return }
        print("[SonicVM] Stopping session")
        isActive = false
        statusText = "Point at objects to explore"

        arSessionManager.stop()
        hapticEngine.stop()
        spatialAudioEngine.stop()
        visionDetector.stop()
    }

    // MARK: - Processing

    func processDepthFrame(_ frame: DepthFrame) {
        closestDistance = frame.closestDistance

        // Select pattern based on distance thresholds
        let pattern: HapticPattern
        if frame.closestDistance < 0.3 {
            pattern = .collision
        } else {
            let adjustedIntensity = Float(frame.intensityFactor * hapticIntensity)
            pattern = .proximity(intensity: adjustedIntensity)
        }

        // User intensity is already baked into .proximity pattern via adjustedIntensity.
        // Only apply user scaling for .collision (which has fixed values).
        let userScale: Double = (frame.closestDistance < 0.3) ? hapticIntensity : 1.0
        hapticEngine.play(pattern: pattern, intensity: userScale)

        spatialAudioEngine.playProximityTone(
            distance: frame.closestDistance,
            angle: frame.dominantAngle
        )

        // Update status with depth info (only if no vision detections are showing)
        if detectedObjects.isEmpty {
            if frame.closestDistance < 0.3 {
                statusText = "CLOSE \(String(format: "%.1f", frame.closestDistance))m"
            } else if frame.closestDistance < 0.5 {
                statusText = "Object very close: \(String(format: "%.1f", frame.closestDistance))m"
            } else {
                statusText = "Scanning... \(String(format: "%.1f", frame.closestDistance))m"
            }
        }
    }
}
