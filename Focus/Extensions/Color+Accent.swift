import SwiftUI

// MARK: - ShapeStyle+AccentMixed

/// Accent-mixed color variants available as `ShapeStyle` static properties.
///
/// Each property blends a standard SwiftUI semantic color with the app's
/// accent color at 20%, producing a tinted palette suitable for status
/// indicators and category badges.
extension ShapeStyle where Self == Color {

    // MARK: - Warm

    /// Red mixed with the accent color at 20%.
    static var accentedRed: Color { .red.mix(with: .accentColor, by: 0.2) }

    /// Orange mixed with the accent color at 20%.
    static var accentedOrange: Color { .orange.mix(with: .accentColor, by: 0.2) }

    /// Yellow mixed with the accent color at 20%.
    static var accentedYellow: Color { .yellow.mix(with: .accentColor, by: 0.2) }

    /// Brown mixed with the accent color at 20%.
    static var accentedBrown: Color { .brown.mix(with: .accentColor, by: 0.2) }

    // MARK: - Cool

    /// Green mixed with the accent color at 20%.
    static var accentedGreen: Color { .green.mix(with: .accentColor, by: 0.2) }

    /// Mint mixed with the accent color at 20%.
    static var accentedMint: Color { .mint.mix(with: .accentColor, by: 0.2) }

    /// Teal mixed with the accent color at 20%.
    static var accentedTeal: Color { .teal.mix(with: .accentColor, by: 0.2) }

    /// Cyan mixed with the accent color at 20%.
    static var accentedCyan: Color { .cyan.mix(with: .accentColor, by: 0.2) }

    /// Blue mixed with the accent color at 20%.
    static var accentedBlue: Color { .blue.mix(with: .accentColor, by: 0.2) }

    /// Indigo mixed with the accent color at 20%.
    static var accentedIndigo: Color { .indigo.mix(with: .accentColor, by: 0.2) }

    /// Purple mixed with the accent color at 20%.
    static var accentedPurple: Color { .purple.mix(with: .accentColor, by: 0.2) }

    /// Pink mixed with the accent color at 20%.
    static var accentedPink: Color { .pink.mix(with: .accentColor, by: 0.2) }

    // MARK: - Neutral

    /// White mixed with the accent color at 20%.
    static var accentedWhite: Color { .white.mix(with: .accentColor, by: 0.2) }

    /// Gray mixed with the accent color at 20%.
    static var accentedGray: Color { .gray.mix(with: .accentColor, by: 0.2) }

    /// Black mixed with the accent color at 20%.
    static var accentedBlack: Color { .black.mix(with: .accentColor, by: 0.2) }
}
