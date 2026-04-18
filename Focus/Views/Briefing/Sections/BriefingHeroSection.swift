import SwiftUI

// MARK: - BriefingHeroSection

/// The editorial hero block at the top of the Focus Briefing.
///
/// Renders the volume eyebrow, two-line serif verdict (with a tone-matched
/// highlight band on the second line), and the three ranked attention cards.
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
                Text("The Briefing · Vol. \(volume)")
                    .font(BriefingFont.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(BriefingColor.ink3)

                Spacer()

                Text(weekRange)
                    .font(BriefingFont.eyebrow)
                    .foregroundStyle(BriefingColor.ink4)
            }

            // MARK: Verdict
            VStack(alignment: .leading, spacing: 4) {
                Text(hero.verdictA)
                    .font(BriefingFont.hero)
                    .foregroundStyle(BriefingColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(hero.verdictB)
                    .font(BriefingFont.hero)
                    .foregroundStyle(BriefingColor.ink)
                    .briefingHighlight(highlightColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // MARK: Attention cards
            VStack(spacing: 10) {
                ForEach(Array(attention.enumerated()), id: \.offset) { _, item in
                    AttentionCardView(item: item) {
                        onAttentionAction(item)
                    }
                }
            }
        }
        .padding(.horizontal, BriefingLayout.gutter)
    }

    // MARK: - Helpers

    /// The highlight band color derived from `hero.highlight`.
    private var highlightColor: Color {
        switch hero.highlight {
        case .red: return BriefingColor.red
        case .blue: return BriefingColor.blue
        case .neutral: return BriefingColor.ink4
        }
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
