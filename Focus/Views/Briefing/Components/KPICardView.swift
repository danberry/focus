import SwiftUI

// MARK: - KPICardView

/// A single KPI card used in the briefing's KPI strip and security section.
///
/// Renders an uppercase eyebrow title, a hero or supporting numeric value, an
/// optional delta label, and an optional sparkline. Tone drives the underlying
/// card fill via ``BriefingCardModifier``.
struct KPICardView: View {

    // MARK: - Properties

    /// The uppercase eyebrow label, e.g. `"Shipping"`.
    let title: String

    /// Pre-formatted value shown as the card's primary number, or `"—"` when unavailable.
    let value: String

    /// Optional supporting delta line, e.g. `"↑ 18%"`.
    var deltaLabel: String? = nil

    /// Optional sparkline values in the range `0.0`–`1.0`.
    var spark: [Double]? = nil

    /// When `true`, the bar at the highest spark value is highlighted in green.
    var highlightPeak: Bool = false

    /// The semantic tone that drives the card's fill and border.
    var tone: BriefingTone = .neutral

    /// When `true`, the value renders at hero size; otherwise at supporting size.
    var isHero: Bool = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(BriefingColor.ink3)

            Text(value)
                .font(isHero ? BriefingFont.kpiHero : BriefingFont.kpiSupporting)
                .foregroundStyle(BriefingColor.ink)

            if let deltaLabel {
                Text(deltaLabel)
                    .font(BriefingFont.meta)
                    .foregroundStyle(BriefingColor.ink3)
            }

            if let spark {
                BriefingSparkBarView(values: spark, tone: tone, highlightPeak: highlightPeak)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        KPICardView(
            title: "Shipping",
            value: "142",
            deltaLabel: "↑ 18%",
            spark: [0.3, 0.5, 0.6, 0.4, 0.7, 0.8, 0.6, 0.9, 0.7, 1.0],
            tone: .neutral,
            isHero: true
        )
        KPICardView(
            title: "Security Debt",
            value: "37",
            deltaLabel: "+6 critical",
            spark: [0.2, 0.3, 0.4, 0.5, 0.6, 0.5, 0.7, 0.8, 0.9, 1.0],
            tone: .red
        )
    }
    .padding()
}
