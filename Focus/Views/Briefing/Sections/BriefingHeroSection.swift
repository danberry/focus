import SwiftUI

// MARK: - BriefingHeroSection

/// The editorial hero block at the top of the Focus Briefing.
///
/// Renders the volume eyebrow, two-line serif verdict (with a tone-matched
/// underline on the emphasis word in the second line), and the three ranked attention cards.
struct BriefingHeroSection: View {

    // MARK: - Properties

    /// The two-part hero verdict shown beneath the eyebrow row.
    let hero: BriefingHero

    /// The three ranked attention items rendered below the verdict.
    let attention: [BriefingAttentionItem]

    /// Human-readable date range string for the covered week.
    let weekRange: String

    /// The ISO week-of-year volume number shown in the eyebrow.
    let volume: Int

    /// Closure invoked when an attention card's action button is tapped.
    var onAttentionAction: (BriefingAttentionItem) -> Void = { _ in }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: Eyebrow
            HStack {
                Text("The Brief · Vol. \(volume)")
                Spacer()
                Text("Week of " + weekRange)
            }
            .font(BriefingFont.eyebrow)
            .textCase(.uppercase)
            .foregroundStyle(BriefingColor.ink3)

            // MARK: Verdict
            Text(verdictAttributed)
                .font(BriefingFont.hero)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)
            
            Text("Look into the following")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(BriefingColor.ink3)

            // MARK: Attention cards
            VStack(spacing: 10) {
                ForEach(Array(attention.enumerated()), id: \.offset) { _, item in
                    AttentionCardView(item: item) {
                        onAttentionAction(item)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// The tone-matched underline color for the emphasis word.
    private var emphasisColor: Color {
        switch hero.highlight {
        case .red: Color.accentColor
        case .blue: Color.customBlue
        case .neutral: Color.gray800
        }
    }

    /// Both verdict lines joined by a newline, with `highlightWord` underlined in the tone color.
    private var verdictAttributed: AttributedString {
        var str = AttributedString(hero.verdictA + "\n" + hero.verdictB)
        if let range = str.range(of: hero.highlightWord, options: .caseInsensitive) {
            str[range].underlineStyle = Text.LineStyle(pattern: .solid, color: emphasisColor)
        }
        return str
    }
}

// MARK: - Preview

#Preview {
    let placeholder = Briefing.placeholder
    return BriefingHeroSection(
        hero: placeholder.hero,
        attention: placeholder.attention,
        weekRange: placeholder.weekRange,
        volume: placeholder.volume
    )
    .padding(.vertical)
}
