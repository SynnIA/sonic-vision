import Foundation
import simd

struct DetectedObject: Identifiable {
    let id: UUID
    let label: String
    let confidence: Float
    let distance: Float
    let position: SIMD3<Float>

    init(label: String, confidence: Float, distance: Float, position: SIMD3<Float>) {
        self.id = UUID()
        self.label = label
        self.confidence = confidence
        self.distance = distance
        self.position = position
    }
}
