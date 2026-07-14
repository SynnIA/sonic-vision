import SwiftUI

// MARK: - Animation Constants

enum Anim {
    // Springs
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)

    // Durations
    static let fast: Double = 0.2
    static let standard: Double = 0.4
    static let slow: Double = 0.6

    // Interactive scales
    static let pressScale: CGFloat = 0.95

    // Transitions
    static let slideUp: AnyTransition = .move(edge: .bottom).combined(with: .opacity)
    static let scaleIn: AnyTransition = .scale(scale: 0.8).combined(with: .opacity)
}

// MARK: - Typography (San Francisco Rounded)

enum Typo {
    /// 48pt Bold — distance readings, critical numbers
    static let display = Font.system(size: 48, weight: .bold, design: .rounded)

    /// 28pt Bold — screen titles
    static let titleLarge = Font.system(size: 28, weight: .bold, design: .rounded)

    /// 22pt Semibold — section titles
    static let titleMedium = Font.system(size: 22, weight: .semibold, design: .rounded)

    /// 17pt Semibold — primary labels
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)

    /// 15pt Medium — body text
    static let body = Font.system(size: 15, weight: .medium, design: .rounded)

    /// 13pt Regular — secondary labels
    static let subheadline = Font.system(size: 13, weight: .regular, design: .rounded)

    /// 12pt Regular — metadata, distances
    static let caption = Font.system(size: 12, weight: .regular, design: .rounded)

    /// 10pt Medium — tags, badges
    static let tag = Font.system(size: 10, weight: .medium, design: .rounded)
}

// MARK: - Spacing

enum Space {
    static let xxl: CGFloat = 32
    static let xl: CGFloat = 24
    static let lg: CGFloat = 16
    static let md: CGFloat = 12
    static let sm: CGFloat = 8
    static let xs: CGFloat = 4
}

// MARK: - Radius

enum Radius {
    static let panel: CGFloat = 24
    static let card: CGFloat = 16
    static let button: CGFloat = 14
    static let pill: CGFloat = 100
}
