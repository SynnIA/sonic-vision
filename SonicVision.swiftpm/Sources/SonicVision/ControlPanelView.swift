import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var viewModel: SonicViewModel
    @State private var isButtonPressed = false

    var body: some View {
        LiquidGlassCard {
            VStack(spacing: Space.xl) {
                // Start/Stop toggle
                Button {
                    withAnimation(Anim.spring) {
                        if viewModel.isActive {
                            viewModel.stopSession()
                        } else {
                            viewModel.startSession()
                        }
                    }
                } label: {
                    HStack(spacing: Space.sm) {
                        Image(systemName: viewModel.isActive ? "stop.fill" : "play.fill")
                            .font(Typo.body)
                        Text(viewModel.isActive ? "Stop" : "Start")
                            .font(Typo.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        viewModel.isActive ? Color.red : Color.blue,
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    )
                    .foregroundStyle(.white)
                }
                .scaleEffect(isButtonPressed ? Anim.pressScale : 1.0)
                .animation(Anim.spring, value: isButtonPressed)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isButtonPressed = true }
                        .onEnded { _ in isButtonPressed = false }
                )
                .accessibilityLabel(viewModel.isActive ? "Stop scanning" : "Start scanning")

                // Haptic intensity slider
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Haptic Intensity")
                        .font(Typo.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: Space.md) {
                        Image(systemName: "hand.tap")
                            .foregroundStyle(.secondary)
                        Slider(value: $viewModel.hapticIntensity, in: 0.2...1.0, step: 0.1)
                            .tint(.blue)
                        Text("\(Int(viewModel.hapticIntensity * 100))%")
                            .font(Typo.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Haptic intensity \(Int(viewModel.hapticIntensity * 100)) percent")

                // Status row
                HStack(spacing: Space.sm) {
                    // Animated status dot
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.3))
                            .frame(width: 18, height: 18)
                            .scaleEffect(viewModel.isActive ? 1.5 : 1.0)
                            .opacity(viewModel.isActive ? 0.0 : 0.0)
                            .animation(
                                viewModel.isActive
                                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                                    : .default,
                                value: viewModel.isActive
                            )
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                    }

                    Text(viewModel.statusText)
                        .font(Typo.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    // Detection count badge
                    if viewModel.isActive && !viewModel.detectedObjects.isEmpty {
                        HStack(spacing: Space.xs) {
                            Image(systemName: "eye.fill")
                                .font(Typo.tag)
                            Text("\(viewModel.detectedObjects.count)")
                                .font(Typo.tag)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, Space.xs)
                        .background(.blue, in: Capsule())
                        .transition(Anim.scaleIn)
                    }
                }
                .animation(Anim.spring, value: viewModel.detectedObjects.isEmpty)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Status: \(viewModel.statusText)")
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.xl)
    }

    private var statusColor: Color {
        if !viewModel.isActive { return .gray }
        if !viewModel.detectedObjects.isEmpty { return .blue }
        return .green
    }
}
