import SwiftUI

// MARK: - StalePRCountKPICardView

/// Stale PR Count KPI card shown in the briefing KPI strip.
///
/// Displays the count of open pull requests that have been open longer than the
/// stale threshold, with an optional week-over-week delta arrow and oldest-age subtitle.
struct StalePRCountKPICardView: View {

    // MARK: - Properties

    let stalePRCount: BriefingKPIStalePRCount

    // MARK: - Body

    var body: some View {
        KPICardView(
            title: "Stale PRs",
            value: "\(stalePRCount.value)",
            inlineDeltaLabel: deltaLabel,
            deltaLabel: subtitle
        )
    }

    // MARK: - Helpers

    private var deltaLabel: String? {
        guard let prior = stalePRCount.priorWeekValue else { return nil }
        let delta = stalePRCount.value - prior
        if delta == 0 { return "→" }
        return delta > 0 ? "↑" : "↓"
    }

    private var subtitle: String? {
        guard let oldest = stalePRCount.oldestAgeDays else { return ">14d open" }
        return "oldest \(oldest)d open"
    }
}

// MARK: - Preview

#Preview {
    StalePRCountKPICardView(
        stalePRCount: BriefingKPIStalePRCount(value: 5, oldestAgeDays: 23, priorWeekValue: 4)
    )
    .padding()
    .background(Color.black)
}
