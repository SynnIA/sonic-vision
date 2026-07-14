import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = SonicViewModel()
    @State private var isViewReady = false
    @State private var showOnboarding = true

    var body: some View {
        ZStack {
            // AR Camera background
            if isViewReady {
                ARCameraView(viewModel: viewModel)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            // Sonar pulse overlay (centered, behind UI)
            if viewModel.isActive {
                SonarOverlayView(
                    isScanning: viewModel.isActive,
                    closestDistance: viewModel.closestDistance
                )
                .allowsHitTesting(false)
            }

            // Detected objects overlay
            if viewModel.isActive && !viewModel.detectedObjects.isEmpty {
                DetectionOverlay(objects: viewModel.detectedObjects)
                    .allowsHitTesting(false)
                    .transition(Anim.scaleIn)
            }

            // UI Chrome
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Sonic Vision")
                            .font(Typo.titleLarge)
                            .foregroundStyle(.white)
                        Text("Spatial Awareness")
                            .font(Typo.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    AccessibilityBadge()
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)

                Spacer()

                // Onboarding hint (first launch)
                if showOnboarding && !viewModel.isActive {
                    OnboardingHint()
                        .transition(Anim.slideUp)
                        .onTapGesture {
                            withAnimation(Anim.spring) { showOnboarding = false }
                        }
                }

                // Bottom controls
                ControlPanelView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.checkPermissions()
            DispatchQueue.main.async {
                isViewReady = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(Anim.gentle) { showOnboarding = false }
            }
        }
        .alert("Camera Access Required", isPresented: $viewModel.showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sonic Vision needs camera access to detect obstacles with the LiDAR sensor. Please enable it in Settings.")
        }
    }
}

// MARK: - Detection Overlay

private struct DetectionOverlay: View {
    let objects: [DetectedObject]

    var body: some View {
        VStack {
            HStack(spacing: Space.sm) {
                ForEach(objects) { obj in
                    DetectionPill(object: obj)
                        .transition(Anim.scaleIn)
                }
            }
            .padding(.top, 80)
            .animation(Anim.spring, value: objects.map(\.id))
            Spacer()
        }
    }
}

private struct DetectionPill: View {
    let object: DetectedObject

    private var urgencyColor: Color {
        if object.distance < 0.5 { return .red }
        if object.distance < 1.5 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(urgencyColor)
                .frame(width: 8, height: 8)
            Text(object.label.capitalized)
                .font(Typo.tag)
                .fontWeight(.bold)
            Text("\(String(format: "%.1f", object.distance))m")
                .font(Typo.tag)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(urgencyColor.opacity(0.4), lineWidth: 0.5))
    }
}

// MARK: - Onboarding Hint

private struct OnboardingHint: View {
    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: "ipad.landscape")
                .font(.title2)
                .symbolEffect(.pulse, options: .repeating)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Point iPad at objects")
                    .font(Typo.headline)
                Text("Tap Start to begin scanning")
                    .font(Typo.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.bottom, Space.sm)
    }
}
