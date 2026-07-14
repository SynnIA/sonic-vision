import Foundation

struct DepthFrame {
    let closestDistance: Float
    let dominantAngle: Float
    let intensityFactor: Double
    let timestamp: TimeInterval

    init(closestDistance: Float, dominantAngle: Float, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.closestDistance = closestDistance
        self.dominantAngle = dominantAngle
        self.timestamp = timestamp

        // Map distance to intensity: 0.3m → 1.0, 3.0m → 0.1
        let clamped = min(max(closestDistance, 0.3), 3.0)
        let normalized = (clamped - 0.3) / (3.0 - 0.3)
        self.intensityFactor = Double(1.0 - normalized * 0.9)
    }
}
