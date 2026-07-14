import SwiftUI

struct AccessibilityBadge: View {
    @State private var showDisclaimer = false

    var body: some View {
        Button {
            showDisclaimer = true
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityLabel("Information and disclaimer")
        .sheet(isPresented: $showDisclaimer) {
            DisclaimerSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct DisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    // Header
                    HStack(spacing: Space.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text("Important Notice")
                            .font(Typo.titleLarge)
                    }
                    .padding(.bottom, Space.sm)

                    // Not a medical device
                    SectionCard(
                        icon: "cross.circle",
                        title: "Not a Medical Device",
                        content: "Sonic Vision is NOT a medical device, safety equipment, or certified assistive technology. It has not been evaluated or approved by any medical or regulatory authority."
                    )

                    // Complementary tool
                    SectionCard(
                        icon: "hand.raised.circle",
                        title: "Complementary Tool Only",
                        content: "This application is designed as a complementary exploration tool. It provides experimental spatial audio and haptic feedback based on depth sensing."
                    )

                    // Does not replace
                    VStack(alignment: .leading, spacing: Space.md) {
                        Label("Does NOT Replace", systemImage: "xmark.shield")
                            .font(Typo.headline)
                            .foregroundStyle(.red)

                        VStack(alignment: .leading, spacing: Space.sm) {
                            BulletPoint("A white cane or mobility aid")
                            BulletPoint("A guide dog")
                            BulletPoint("Orientation & mobility training")
                            BulletPoint("Professional accessibility assessments")
                            BulletPoint("Any established assistive technology")
                        }
                    }
                    .padding(Space.lg)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    )

                    // Privacy
                    SectionCard(
                        icon: "lock.shield",
                        title: "Privacy",
                        content: "All processing happens entirely on-device. No camera data, depth information, or usage data is ever transmitted, stored, or shared. Sonic Vision works 100% offline."
                    )
                }
                .padding(Space.xl)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Typo.headline)
                }
            }
        }
    }
}

private struct SectionCard: View {
    let icon: String
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Label(title, systemImage: icon)
                .font(Typo.headline)
            Text(content)
                .font(Typo.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        )
    }
}

private struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Circle()
                .fill(.secondary)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(Typo.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
