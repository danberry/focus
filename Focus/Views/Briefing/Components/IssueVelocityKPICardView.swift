import SwiftUI

// MARK: - IssueVelocityKPICardView

/// Displays the count of issues opened and closed during the briefing week.
struct IssueVelocityKPICardView: View {

    // MARK: - Properties

    /// The issue velocity data to render.
    let issueVelocity: BriefingKPIIssueVelocity

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Issues")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(.gray700)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(issueVelocity.closed)")
                    .font(BriefingFont.kpiHero)
                    .foregroundStyle(.white)
                if let delta = deltaLabel {
                    Text(delta)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            Text("\(issueVelocity.opened) opened · \(issueVelocity.closed) closed")
                .font(BriefingFont.meta)
                .foregroundStyle(.gray700)

            BriefingSparkBarView(values: normalizedSpark)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    /// Closed-issue counts normalized to `0.0`–`1.0` against the week's peak day.
    private var normalizedSpark: [Double] {
        let counts = issueVelocity.dailyClosedCounts
        guard let peak = counts.max(), peak > 0 else { return counts.map { _ in 0.0 } }
        return counts.map { Double($0) / Double(peak) }
    }

    /// Week-over-week direction indicator for closed issues, or `nil` when no prior value is available.
    private var deltaLabel: String? {
        guard let prior = issueVelocity.priorWeekClosed, prior > 0 else { return nil }
        let diff = issueVelocity.closed - prior
        if diff == 0 { return "→" }
        return diff > 0 ? "↑" : "↓"
    }
}

// MARK: - Preview

#Preview {
    IssueVelocityKPICardView(
        issueVelocity: BriefingKPIIssueVelocity(
            opened: 14,
            closed: 11,
            dailyClosedCounts: [1, 2, 3, 1, 2, 1, 1],
            priorWeekClosed: 8
        )
    )
    .padding()
    .background(Color.black)
}
