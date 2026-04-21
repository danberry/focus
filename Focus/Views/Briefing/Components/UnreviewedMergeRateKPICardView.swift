import SwiftUI

// MARK: - UnreviewedMergeRateKPICardView

/// The Unreviewed Merge Rate KPI card shown in the briefing KPI strip.
///
/// Displays the percentage of merged PRs that received no review before merging,
/// with an optional week-over-week delta arrow and an unreviewed/total subtitle.
struct UnreviewedMergeRateKPICardView: View {

    // MARK: - Properties

    let unreviewedMergeRate: BriefingKPIUnreviewedMergeRate

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Unreviewed")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(.gray700)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(unreviewedMergeRate.value)%")
                    .font(BriefingFont.kpiHero)

                if let delta {
                    Text(delta)
                        .font(.system(size: 34, weight: .semibold))
                }
            }
            .foregroundStyle(.white)

            Text("\(unreviewedMergeRate.unreviewed) of \(unreviewedMergeRate.total) PRs")
                .font(BriefingFont.meta)
                .foregroundStyle(.gray700)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private var delta: String? {
        guard let prior = unreviewedMergeRate.priorWeekValue else { return nil }
        let diff = unreviewedMergeRate.value - prior
        if diff == 0 { return "→" }
        // Higher unreviewed rate is worse — ↑ is bad.
        return diff > 0 ? "↑" : "↓"
    }
}

// MARK: - Preview

#Preview {
    UnreviewedMergeRateKPICardView(
        unreviewedMergeRate: BriefingKPIUnreviewedMergeRate(
            value: 12,
            unreviewed: 9,
            total: 73,
            priorWeekValue: 8
        )
    )
    .padding()
}
