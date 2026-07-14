import SwiftUI

/// Animated sonar pulse overlay that visualizes LiDAR depth scanning.
/// Three concentric waves pulse outward with staggered timing,
/// color-coded by proximity (red/orange/cyan).
struct SonarOverlayView: View {
    let isScanning: Bool
    let closestDistance: Float

    @State private var wave1: CGFloat = 0.3
    @State private var wave2: CGFloat = 0.3
    @State private var wave3: CGFloat = 0.3
    @State private var opacity1: Double = 0.0
    @State private var opacity2: Double = 0.0
    @State private var opacity3: Double = 0.0

    private var waveColor: Color {
        if closestDistance < 0.5 { return .red }
        if closestDistance < 1.5 { return .orange }
        return .cyan
    }

    var body: some View {
        ZStack {
            // Wave 1 (fastest)
            Circle()
                .stroke(waveColor.opacity(0.5), lineWidth: 1.5)
                .scaleEffect(wave1)
                .opacity(opacity1)

            // Wave 2 (delayed)
            Circle()
                .stroke(waveColor.opacity(0.35), lineWidth: 1.2)
                .scaleEffect(wave2)
                .opacity(opacity2)

            // Wave 3 (most delayed)
            Circle()
                .stroke(waveColor.opacity(0.2), lineWidth: 1.0)
                .scaleEffect(wave3)
                .opacity(opacity3)

            // Center dot
            Circle()
                .fill(waveColor)
                .frame(width: 6, height: 6)
                .opacity(isScanning ? 0.8 : 0)
        }
        .frame(width: 240, height: 240)
        .onChange(of: isScanning) { _, scanning in
            if scanning { startPulsing() } else { stopPulsing() }
        }
        .onAppear {
            if isScanning { startPulsing() }
        }
    }

    private func startPulsing() {
        // Reset to initial state
        wave1 = 0.3; wave2 = 0.3; wave3 = 0.3
        opacity1 = 0; opacity2 = 0; opacity3 = 0

        // Wave 1 — immediate
        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
            wave1 = 1.8
            opacity1 = 0.6
        }
        // Fade out separately
        withAnimation(.easeIn(duration: 2.0).repeatForever(autoreverses: false).delay(0.3)) {
            opacity1 = 0.0
        }

        // Wave 2 — delayed 0.6s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                wave2 = 1.8
            }
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                opacity2 = 0.5
            }
            withAnimation(.easeIn(duration: 2.0).repeatForever(autoreverses: false).delay(0.3)) {
                opacity2 = 0.0
            }
        }

        // Wave 3 — delayed 1.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                wave3 = 1.8
            }
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                opacity3 = 0.4
            }
            withAnimation(.easeIn(duration: 2.0).repeatForever(autoreverses: false).delay(0.3)) {
                opacity3 = 0.0
            }
        }
    }

    private func stopPulsing() {
        withAnimation(.easeOut(duration: 0.4)) {
            wave1 = 0.3; wave2 = 0.3; wave3 = 0.3
            opacity1 = 0; opacity2 = 0; opacity3 = 0
        }
    }
}
