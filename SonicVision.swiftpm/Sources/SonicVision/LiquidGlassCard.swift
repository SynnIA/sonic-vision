import SwiftUI

struct LiquidGlassCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(Space.xl)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}
