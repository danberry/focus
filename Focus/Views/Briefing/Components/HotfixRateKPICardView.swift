import SwiftUI

// MARK: - HotfixRateKPICardView

/// Hotfix Rate KPI card shown in the briefing KPI strip.
///
/// Displays the percentage of merged PRs identified as hotfixes this week,
/// with an optional week-over-week delta arrow and a supporting count subtitle.
/// Lower is better — a rising hotfix rate signals increasing unplanned work.
struct HotfixRateKPICardView: View {

    // MARK: - Properties

    let hotfixRate: BriefingKPIHotfixRate

    // MARK: - Body

    var body: some View {
        KPICardView(
            title: "Hotfix Rate",
            value: "\(hotfixRate.value)%",
            inlineDeltaLabel: deltaLabel,
            deltaLabel: subtitle
        )
    }

    // MARK: - Helpers

    private var deltaLabel: String? {
        guard let prior = hotfixRate.priorWeekValue else { return nil }
        let delta = hotfixRate.value - prior
        if delta == 0 { return "→" }
        // Higher hotfix rate is worse — arrow reflects quality direction.
        return delta > 0 ? "↑" : "↓"
    }

    private var subtitle: String? {
        "\(hotfixRate.hotfixCount) of \(hotfixRate.totalMerged)"
    }
}

// MARK: - Preview

#Preview {
    HotfixRateKPICardView(
        hotfixRate: BriefingKPIHotfixRate(value: 11, hotfixCount: 8, totalMerged: 73, priorWeekValue: 15)
    )
    .padding()
    .background(Color.black)
}
