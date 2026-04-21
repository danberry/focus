import SwiftUI

// MARK: - KPICardView

/// A single KPI card used in the briefing's KPI strip and security section.
struct KPICardView: View {

    // MARK: - Properties

    /// The uppercase eyebrow label, e.g. `"Shipping"`.
    let title: String

    /// Pre-formatted value shown as the card's primary number, or `"—"` when unavailable.
    let value: String

    /// Optional delta rendered inline with the value at last-baseline alignment, e.g. `"↑ 4pp"`.
    var inlineDeltaLabel: String? = nil

    /// Optional supporting delta line, e.g. `"↑ 18%"`.
    var deltaLabel: String? = nil

    /// The semantic tone that drives the card's fill and border.
    var tone: BriefingTone = .neutral

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(.gray700)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(BriefingFont.kpiSupporting)

                if let inlineDeltaLabel {
                    Text(inlineDeltaLabel)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(.white)

            if let deltaLabel {
                Text(deltaLabel)
                    .font(BriefingFont.meta)
                    .foregroundStyle(.gray700)
            }

}
        .frame(minWidth: 60, alignment: .leading)
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        KPICardView(
            title: "Cycle Time",
            value: "18h",
            inlineDeltaLabel: "↓",
            deltaLabel: "open → merge",
            tone: .neutral
        )
        KPICardView(
            title: "CI Pass",
            value: "94%",
            inlineDeltaLabel: "↑",
            deltaLabel: "target 95%",
            tone: .neutral
        )
    }
    .padding()
}
