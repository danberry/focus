import SwiftUI

// MARK: - MergeRateKPICardView

/// Merge Rate KPI card shown in the briefing KPI strip.
///
/// Displays the percentage of PRs opened this week that were also merged this week,
/// with a "N of M PRs" subtitle and an optional week-over-week delta arrow.
/// Values above 100% (backlog clearance) are displayed as-is rather than capped.
struct MergeRateKPICardView: View {

    // MARK: - Properties

    let mergeRate: BriefingKPIMergeRate

    // MARK: - Body

    var body: some View {
        KPICardView(
            title: "Merge Rate",
            value: "\(mergeRate.value)%",
            inlineDeltaLabel: deltaLabel,
            deltaLabel: "\(mergeRate.merged) of \(mergeRate.opened) PRs"
        )
    }

    // MARK: - Helpers

    private var deltaLabel: String? {
        guard let prior = mergeRate.priorWeekValue else { return nil }
        let delta = mergeRate.value - prior
        if delta == 0 { return "→" }
        return delta > 0 ? "↑" : "↓"
    }
}

// MARK: - Preview

#Preview {
    MergeRateKPICardView(
        mergeRate: BriefingKPIMergeRate(value: 87, merged: 73, opened: 84, priorWeekValue: 79)
    )
    .padding()
    .background(Color.black)
}
