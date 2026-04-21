import SwiftUI

// MARK: - ActiveContributorsKPICardView

/// Active Contributors KPI card shown in the briefing KPI strip.
///
/// Displays the count of tracked members who made at least one contribution
/// during the briefing week, with an optional week-over-week delta arrow.
struct ActiveContributorsKPICardView: View {

    // MARK: - Properties

    let activeContributors: BriefingKPIActiveContributors

    // MARK: - Body

    var body: some View {
        KPICardView(
            title: "Contributors",
            value: "\(activeContributors.value)",
            inlineDeltaLabel: deltaLabel,
            deltaLabel: subtitle
        )
    }

    // MARK: - Helpers

    private var deltaLabel: String? {
        guard let prior = activeContributors.priorWeekValue else { return nil }
        let delta = activeContributors.value - prior
        if delta == 0 { return "→" }
        return delta > 0 ? "↑" : "↓"
    }

    private var subtitle: String? {
        "of \(activeContributors.totalTracked) tracked"
    }
}

// MARK: - Preview

#Preview {
    ActiveContributorsKPICardView(
        activeContributors: BriefingKPIActiveContributors(value: 28, totalTracked: 34, priorWeekValue: 25)
    )
    .padding()
}
