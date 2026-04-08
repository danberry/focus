import SwiftUI

// MARK: - ShapeStyle+AccentMixed

extension ShapeStyle where Self == Color {
    static var accentedRed: Color { .red.mix(with: .accentColor, by: 0.3) }
    static var accentedOrange: Color { .orange.mix(with: .accentColor, by: 0.3) }
    static var accentedYellow: Color { .yellow.mix(with: .accentColor, by: 0.3) }
    static var accentedGreen: Color { .green.mix(with: .accentColor, by: 0.3) }
    static var accentedMint: Color { .mint.mix(with: .accentColor, by: 0.3) }
    static var accentedTeal: Color { .teal.mix(with: .accentColor, by: 0.3) }
    static var accentedCyan: Color { .cyan.mix(with: .accentColor, by: 0.3) }
    static var accentedBlue: Color { .blue.mix(with: .accentColor, by: 0.3) }
    static var accentedIndigo: Color { .indigo.mix(with: .accentColor, by: 0.3) }
    static var accentedPurple: Color { .purple.mix(with: .accentColor, by: 0.3) }
    static var accentedPink: Color { .pink.mix(with: .accentColor, by: 0.3) }
    static var accentedBrown: Color { .brown.mix(with: .accentColor, by: 0.3) }
    static var accentedWhite: Color { .white.mix(with: .accentColor, by: 0.3) }
    static var accentedGray: Color { .gray.mix(with: .accentColor, by: 0.3) }
    static var accentedBlack: Color { .black.mix(with: .accentColor, by: 0.3) }
}
