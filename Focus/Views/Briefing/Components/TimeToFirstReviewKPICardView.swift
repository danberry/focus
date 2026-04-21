import SwiftUI

// MARK: - TimeToFirstReviewKPICardView

/// The Time to First Review KPI card shown in the briefing KPI strip.
///
/// Displays the median time from PR open to first review for the week with an optional
/// week-over-week delta arrow, a subtitle line, and a 7-day bar sparkline where
/// the peak day is highlighted.
struct TimeToFirstReviewKPICardView: View {

    // MARK: - Properties

    let timeToFirstReview: BriefingKPITimeToFirstReview

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("First Review")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(.gray700)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(formattedValue)
                    .font(BriefingFont.kpiHero)

                if let delta {
                    Text(delta)
                        .font(.system(size: 34, weight: .semibold))
                }
            }
            .foregroundStyle(.white)

            Text("open → review")
                .font(BriefingFont.meta)
                .foregroundStyle(.gray700)

            BriefingSparkBarView(values: normalizedSpark)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private var formattedValue: String {
        let h = timeToFirstReview.value
        if h < 24 { return "\(h)h" }
        let days = Int((Double(h) / 24).rounded())
        return "\(days)d"
    }

    private var normalizedSpark: [Double] {
        let medians = timeToFirstReview.dailyMedians
        guard let peak = medians.max(), peak > 0 else { return medians.map { _ in 0.0 } }
        return medians.map { Double($0) / Double(peak) }
    }

    private var delta: String? {
        guard let prior = timeToFirstReview.priorWeekValue, prior > 0 else { return nil }
        let diff = timeToFirstReview.value - prior
        if diff == 0 { return "→" }
        // Lower time-to-review is better — flip arrow direction.
        return diff < 0 ? "↓" : "↑"
    }
}

// MARK: - Preview

#Preview {
    TimeToFirstReviewKPICardView(
        timeToFirstReview: BriefingKPITimeToFirstReview(
            value: 6,
            dailyMedians: [8, 5, 6, 9, 4, 7, 6],
            priorWeekValue: 10
        )
    )
    .padding()
}
