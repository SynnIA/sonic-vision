import CoreHaptics

enum HapticPattern {
    case proximity(intensity: Float)
    case collision
    case objectDetected

    func events() -> [CHHapticEvent] {
        switch self {
        case .proximity(let intensity):
            let clampedIntensity = min(max(intensity, 0.0), 1.0)
            let sharpness = clampedIntensity * 0.8
            return [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: 0,
                    duration: 0.2
                )
            ]

        case .collision:
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0
                )
            ]

        case .objectDetected:
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.15
                )
            ]
        }
    }
}
