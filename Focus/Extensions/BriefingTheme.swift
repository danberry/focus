import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - BriefingTone

/// A semantic color tone used to drive the Focus Briefing accent palette.
///
/// `BriefingTone` selects matching fill, border, and foreground colors when
/// applied via ``BriefingCardModifier`` or ``BriefingChipView``.
enum BriefingTone: Hashable {

    /// Red tone — reserved for security alerts, critical counts, and the security section header.
    case red

    /// Blue tone — reserved for idle/blocked members and leading-repo emphasis.
    case blue

    /// Neutral tone — paper surfaces with hairline borders.
    case neutral
}

// MARK: - BriefingColor

/// Static `Color` properties that compose the Focus Briefing palette.
///
/// `BriefingColor` is an enum namespace — it cannot be instantiated. Each property
/// returns a dynamic `Color` whose light- and dark-mode values match the editorial
/// design handoff palette. Hex values are sourced from `design_handoff_focus_briefing/README.md`.
enum BriefingColor {

    // MARK: - Surfaces

    /// Primary paper surface — the page background.
    static let paper: Color = adaptive(light: 0xffffff, dark: 0x141414)

    /// Secondary paper surface — neutral card fill.
    static let paper2: Color = adaptive(light: 0xf3f3f1, dark: 0x1d1d1d)

    /// Tertiary paper surface — recessed wells and avatar backgrounds.
    static let paper3: Color = adaptive(light: 0xe5e5e2, dark: 0x2a2a2a)

    // MARK: - Text

    /// Primary ink — body text and high-emphasis content.
    static let ink: Color = adaptive(light: 0x1c1c1c, dark: 0xf2efe8)

    /// Secondary ink — supporting text.
    static let ink2: Color = adaptive(light: 0x3a3a3a, dark: 0xcfcbc3)

    /// Tertiary ink — meta lines, captions, and low-emphasis labels.
    static let ink3: Color = adaptive(light: 0x6e6e6e, dark: 0x8a8680)

    /// Quaternary ink — disabled states and zero-value spark bars.
    static let ink4: Color = adaptive(light: 0xa8a8a5, dark: 0x56534e)

    // MARK: - Dividers

    /// Primary rule color — section dividers.
    static let rule: Color = adaptive(light: 0xd4d4d0, dark: 0x2e2e2e)

    /// Secondary rule color — neutral card borders.
    static let rule2: Color = adaptive(light: 0xeaeae7, dark: 0x242424)

    // MARK: - Dark Blocks

    /// Charcoal — used for inverted blocks and emphasis surfaces.
    static let charcoal: Color = adaptive(light: 0x1f1f1f, dark: 0x0a0a0a)

    // MARK: - Red Accent

    /// Primary red accent — used for security headers and critical counts.
    static let red: Color = adaptive(light: 0xc8321c, dark: 0xff6a4d)

    /// Secondary red accent — used on dark-toned surfaces.
    static let red2: Color = adaptive(light: 0xa22413, dark: 0xff8a72)

    /// Red background fill for tone-red cards.
    static let redBg: Color = adaptive(light: 0xf4d9d0, dark: 0x3a1a12)

    /// Red border stroke for tone-red cards.
    static let redBd: Color = adaptive(light: 0xe3b0a1, dark: 0x5a2418)

    // MARK: - Blue Accent

    /// Primary blue accent — used for idle/blocked members and leading bars.
    static let blue: Color = adaptive(light: 0x1e3a8a, dark: 0x7a92e8)

    /// Secondary blue accent — used on dark-toned surfaces.
    static let blue2: Color = adaptive(light: 0x152a66, dark: 0xa0b4f0)

    /// Blue background fill for tone-blue cards.
    static let blueBg: Color = adaptive(light: 0xd8def0, dark: 0x1a1f3a)

    /// Blue border stroke for tone-blue cards.
    static let blueBd: Color = adaptive(light: 0xb3bddc, dark: 0x2a3258)

    // MARK: - Private

    /// Builds a SwiftUI `Color` that resolves to different hex values in light and dark mode.
    ///
    /// - Parameters:
    ///   - light: The 0xRRGGBB hex value used in light appearance.
    ///   - dark: The 0xRRGGBB hex value used in dark appearance.
    /// - Returns: A dynamic `Color` backed by a trait-aware `UIColor`.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(briefingHex: dark)
                : UIColor(briefingHex: light)
        })
    }
}

// MARK: - BriefingFont

/// Static `Font` properties used throughout the Focus Briefing layout.
///
/// `BriefingFont` is an enum namespace — it cannot be instantiated. Sizes,
/// weights, and designs match the editorial design handoff specification.
enum BriefingFont {

    // MARK: - Properties

    /// 44pt serif — the hero verdict on the briefing landing page.
    static let hero: Font = .system(size: 88, weight: .medium, design: .serif)

    /// 22pt serif — verdicts shown beneath each section header.
    static let sectionVerdict: Font = .system(size: 22, weight: .medium, design: .serif)

    /// 54pt monospaced-digit — hero KPI numbers.
    static let kpiHero: Font = .system(size: 54, weight: .medium).monospacedDigit()

    /// 24pt monospaced-digit — supporting KPI numbers.
    static let kpiSupporting: Font = .system(size: 24, weight: .medium).monospacedDigit()

    /// 15pt medium — attention card titles.
    static let attentionTitle: Font = .system(size: 18, weight: .medium)

    /// 14pt body — primary card body copy.
    static let body: Font = .system(size: 14)

    /// 10pt monospaced — eyebrow labels above section headers and chips.
    static let eyebrow: Font = .system(size: 13, weight: .medium, design: .monospaced)

    /// 11pt monospaced — meta lines (timestamps, evidence, idle labels).
    static let meta: Font = .system(size: 11, design: .monospaced)
}

// MARK: - BriefingLayout

/// Static layout constants used throughout the Focus Briefing layout.
///
/// `BriefingLayout` is an enum namespace — it cannot be instantiated.
enum BriefingLayout {

    // MARK: - Properties

    /// The horizontal page gutter, in points.
    static let gutter: CGFloat = 20

    /// The corner radius for full-size briefing cards, in points.
    static let cardRadius: CGFloat = 16

    /// The corner radius for compact ("flat") briefing cards, in points.
    static let flatRadius: CGFloat = 12

    /// The vertical gap between sibling sections, in points.
    static let sectionGap: CGFloat = 14
}

// MARK: - BriefingHighlight

/// Applies a horizontal highlight band to text — visually a marker stripe behind the glyphs.
///
/// The band is rendered as a vertical `LinearGradient` sandwiched between two
/// transparent stops at 60% and 94%, producing a flat band of the supplied
/// color across the lower portion of the text bounding box.
struct BriefingHighlight: ViewModifier {

    // MARK: - Properties

    /// The color of the highlight band.
    let color: Color

    // MARK: - Body

    /// Lays the highlight gradient behind `content` along the bottom edge.
    func body(content: Content) -> some View {
        content.background(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.60),
                    .init(color: color.opacity(0.20), location: 0.60),
                    .init(color: color.opacity(0.20), location: 0.94),
                    .init(color: .clear, location: 0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

extension View {

    /// Applies a Briefing-style highlight band behind the receiver.
    ///
    /// - Parameter color: The color of the highlight band.
    /// - Returns: A view with the highlight gradient applied as a background.
    func briefingHighlight(_ color: Color) -> some View {
        modifier(BriefingHighlight(color: color))
    }
}

// MARK: - BriefingCardModifier

/// Applies tone-aware fill and stroke to produce a Focus Briefing card surface.
///
/// The fill, border, and corner radius are derived from the supplied `tone`
/// and `flat` flag. Use the `briefingCard(tone:flat:)` view extension at call sites
/// rather than constructing this modifier directly.
struct BriefingCardModifier: ViewModifier {

    // MARK: - Properties

    /// The semantic tone that determines fill and border colors.
    let tone: BriefingTone

    /// When `true`, uses the smaller compact corner radius. Defaults to `false`.
    var flat: Bool = false

    // MARK: - Body

    /// Wraps `content` in the tone-matched fill and stroke.
    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        )
    }

    // MARK: - Private

    /// The fill color for the current tone.
    private var fill: Color {
        switch tone {
        case .red: return BriefingColor.redBg
        case .blue: return BriefingColor.blueBg
        case .neutral: return BriefingColor.paper
        }
    }

    /// The border color for the current tone.
    private var border: Color {
        switch tone {
        case .red: return BriefingColor.redBd
        case .blue: return BriefingColor.blueBd
        case .neutral: return BriefingColor.rule
        }
    }

    /// The corner radius for the current variant.
    private var radius: CGFloat {
        flat ? BriefingLayout.flatRadius : BriefingLayout.cardRadius
    }
}

extension View {

    /// Applies a Focus Briefing card background to the receiver.
    ///
    /// - Parameters:
    ///   - tone: The semantic tone that drives fill and border colors. Defaults to ``BriefingTone/neutral``.
    ///   - flat: When `true`, uses the compact corner radius. Defaults to `false`.
    /// - Returns: A view with a tone-matched fill and 1pt stroke.
    func briefingCard(tone: BriefingTone = .neutral, flat: Bool = false) -> some View {
        modifier(BriefingCardModifier(tone: tone, flat: flat))
    }
}

// MARK: - UIColor+BriefingHex

private extension UIColor {

    /// Creates a `UIColor` from an 0xRRGGBB hex value.
    ///
    /// - Parameters:
    ///   - briefingHex: The 24-bit color value packed as `0xRRGGBB`.
    ///   - alpha: The alpha component in the range `0...1`. Defaults to `1`.
    convenience init(briefingHex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((briefingHex >> 16) & 0xff) / 255
        let g = CGFloat((briefingHex >> 8) & 0xff) / 255
        let b = CGFloat(briefingHex & 0xff) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
