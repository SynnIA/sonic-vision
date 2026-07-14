import Foundation
@preconcurrency import Vision
import simd
import Combine
import CoreVideo

/// Detects objects in camera frames using Vision framework.
/// Operates 100% on-device with no external dependencies.
/// Pipeline: VNClassifyImageRequest (scene classification) + VNDetectHumanRectanglesRequest
/// + VNDetectRectanglesRequest (geometric shapes).
final class VisionDetector: ObservableObject {

    // MARK: - Published State

    @Published var detectedObjects: [DetectedObject] = []

    // MARK: - Private Properties

    private var requests: [VNRequest] = []
    private let processingQueue = DispatchQueue(label: "com.sonicvision.vision", qos: .userInitiated)
    private var lastProcessTime: TimeInterval = 0
    private let minProcessInterval: TimeInterval = 0.5 // 2 detections/sec max
    private var lastDetectionTime: TimeInterval = 0
    private var isActive = false

    /// Labels relevant to spatial awareness and obstacle avoidance.
    /// VNClassifyImageRequest returns ~1000 categories; we keep only useful ones.
    private let relevantClassifications: Set<String> = [
        // Vehicles
        "car", "truck", "bus", "bicycle", "motorcycle", "scooter", "van",
        // Animals
        "dog", "cat", "bird", "horse",
        // Furniture / obstacles
        "chair", "table", "bench", "couch", "bed", "desk",
        // Infrastructure
        "stairs", "escalator", "elevator", "fence", "gate", "pole",
        "fire_hydrant", "traffic_light", "stop_sign",
        // Objects
        "bag", "suitcase", "stroller", "wheelchair", "umbrella",
        // Terrain
        "tree", "plant", "rock"
    ]

    // MARK: - Per-frame accumulators (written only on processingQueue)

    private var pendingClassifications: [DetectedObject] = []
    private var pendingHumans: [DetectedObject] = []
    private var pendingRects: [DetectedObject] = []
    private var frameCount: Int = 0

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        isActive = true
        setupVision()
        print("[VisionDetector] Started with \(requests.count) requests")
    }

    func stop() {
        isActive = false
        requests.removeAll()
        DispatchQueue.main.async {
            self.detectedObjects = []
        }
        print("[VisionDetector] Stopped")
    }

    // MARK: - Setup

    private func setupVision() {
        var builtRequests: [VNRequest] = []

        // 1. Image classification (built-in, ~1000 categories, no model file)
        let classifyRequest = VNClassifyImageRequest { [weak self] request, error in
            if let error {
                print("[VisionDetector] Classification error: \(error.localizedDescription)")
                self?.pendingClassifications = []
                return
            }
            self?.processClassificationResults(request.results as? [VNClassificationObservation])
        }
        builtRequests.append(classifyRequest)

        // 2. Human body detection (built-in, no model needed)
        let humanRequest = VNDetectHumanRectanglesRequest { [weak self] request, error in
            if let error {
                print("[VisionDetector] Human detection error: \(error.localizedDescription)")
                self?.pendingHumans = []
                return
            }
            self?.processHumanResults(request.results as? [VNHumanObservation])
        }
        humanRequest.upperBodyOnly = false
        builtRequests.append(humanRequest)

        // 3. Rectangle detection (doors, furniture, screens)
        let rectRequest = VNDetectRectanglesRequest { [weak self] request, error in
            if let error {
                print("[VisionDetector] Rectangle detection error: \(error.localizedDescription)")
                self?.pendingRects = []
                return
            }
            self?.processRectangleResults(request.results as? [VNRectangleObservation])
        }
        rectRequest.minimumSize = 0.1
        rectRequest.maximumObservations = 5
        rectRequest.minimumConfidence = 0.6
        rectRequest.minimumAspectRatio = 0.2
        builtRequests.append(rectRequest)

        requests = builtRequests
        print("[VisionDetector] Vision pipeline configured: \(requests.count) requests")
    }

    // MARK: - Frame Processing

    /// Process a camera frame. Called by ViewModel via Combine binding.
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isActive else { return }

        // Throttle: max 2 detections/sec
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastProcessTime >= minProcessInterval else { return }
        lastProcessTime = now

        frameCount += 1
        let currentFrame = frameCount
        print("[VisionDetector] Processing frame #\(currentFrame)")

        // nonisolated(unsafe) suppresses Sendable warning for CVPixelBuffer
        nonisolated(unsafe) let safeBuffer = pixelBuffer

        processingQueue.async { [weak self] in
            guard let self, self.isActive else { return }

            // Reset accumulators for this frame
            self.pendingClassifications = []
            self.pendingHumans = []
            self.pendingRects = []

            let handler = VNImageRequestHandler(cvPixelBuffer: safeBuffer, orientation: .up)

            do {
                // perform() is synchronous — all completion handlers fire on this queue
                // before perform() returns. So after this line, all pending arrays are filled.
                try handler.perform(self.requests)
                self.lastDetectionTime = ProcessInfo.processInfo.systemUptime

                // Merge ONCE after all callbacks complete
                self.publishResults(frameNumber: currentFrame)
            } catch {
                print("[VisionDetector] Processing failed: \(error.localizedDescription)")
            }

            self.clearStaleDetections()
        }
    }

    // MARK: - Result Processing

    private func processClassificationResults(_ observations: [VNClassificationObservation]?) {
        guard let observations else { return }

        // Filter for relevant labels with high confidence
        pendingClassifications = observations
            .filter { $0.confidence > 0.4 && relevantClassifications.contains($0.identifier) }
            .prefix(2)
            .map { obs in
                // Classification is scene-wide — assume centered, estimate distance as mid-range
                let label = obs.identifier.replacingOccurrences(of: "_", with: " ")
                return DetectedObject(
                    label: label,
                    confidence: obs.confidence,
                    distance: 2.0,
                    position: SIMD3<Float>(0, 0, -2.0)
                )
            }
    }

    private func processHumanResults(_ observations: [VNHumanObservation]?) {
        guard let observations, !observations.isEmpty else { return }

        pendingHumans = observations
            .filter { $0.confidence > 0.6 }
            .prefix(3)
            .map { obs in
                let distance = estimateDistanceFromBBox(obs.boundingBox)
                let position = estimatePosition(boundingBox: obs.boundingBox, distance: distance)
                return DetectedObject(
                    label: "person",
                    confidence: obs.confidence,
                    distance: distance,
                    position: position
                )
            }
    }

    private func processRectangleResults(_ observations: [VNRectangleObservation]?) {
        guard let observations, !observations.isEmpty else { return }

        pendingRects = observations
            .filter { $0.confidence > 0.6 }
            .prefix(3)
            .map { obs in
                let label = classifyRectangle(obs)
                let distance = estimateDistanceFromBBox(obs.boundingBox)
                let position = estimatePosition(boundingBox: obs.boundingBox, distance: distance)
                return DetectedObject(
                    label: label,
                    confidence: obs.confidence,
                    distance: distance,
                    position: position
                )
            }
    }

    /// Merges all pending results and publishes once per frame.
    private func publishResults(frameNumber: Int) {
        var merged = pendingClassifications + pendingHumans + pendingRects

        // Sort by confidence, keep top 3
        merged.sort { $0.confidence > $1.confidence }
        let top = Array(merged.prefix(3))

        if !top.isEmpty {
            let labels = top.map { "\($0.label)(\(String(format: "%.0f", $0.confidence * 100))%)" }.joined(separator: ", ")
            print("[VisionDetector] Frame #\(frameNumber) detected: \(labels)")
        }

        DispatchQueue.main.async {
            self.detectedObjects = top
        }
    }

    // MARK: - Classification Heuristics

    /// Classify a rectangle based on its aspect ratio and size.
    private func classifyRectangle(_ observation: VNRectangleObservation) -> String {
        let box = observation.boundingBox
        let aspectRatio = box.width / box.height

        // Tall and narrow -> likely a door
        if aspectRatio < 0.6 && box.height > 0.4 {
            return "door"
        }
        // Wide and short -> likely a table or surface
        if aspectRatio > 1.5 && box.height < 0.3 {
            return "surface"
        }
        // Large area -> likely a wall or large furniture
        if box.width * box.height > 0.25 {
            return "wall"
        }
        // Medium square-ish -> generic object
        if box.width * box.height > 0.05 {
            return "object"
        }
        return "obstacle"
    }

    // MARK: - Distance Estimation

    /// Estimate distance from bounding box size (heuristic, no depth map).
    /// Larger boxes = closer objects.
    private func estimateDistanceFromBBox(_ boundingBox: CGRect) -> Float {
        let area = Float(boundingBox.width * boundingBox.height)
        // area 1.0 (full frame) -> ~0.3m, area 0.01 (tiny) -> ~5.0m
        guard area > 0.001 else { return 5.0 }
        let distance = 1.0 / (area * 3.0 + 0.2)
        return min(max(distance, 0.3), 5.0)
    }

    // MARK: - Position Estimation

    private func estimatePosition(boundingBox: CGRect, distance: Float) -> SIMD3<Float> {
        // Vision bounding box: origin at bottom-left, normalized [0,1]
        let centerX = Float(boundingBox.midX)
        let centerY = Float(boundingBox.midY)

        // Map to [-1, 1] range
        let x = (centerX - 0.5) * 2.0 * distance
        let y = (centerY - 0.5) * 2.0 * distance
        let z = -distance

        return SIMD3<Float>(x, y, z)
    }

    // MARK: - Staleness

    private func clearStaleDetections() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastDetectionTime > 10.0 && !detectedObjects.isEmpty {
            DispatchQueue.main.async {
                self.detectedObjects = []
            }
            print("[VisionDetector] Cleared stale detections")
        }
    }
}
