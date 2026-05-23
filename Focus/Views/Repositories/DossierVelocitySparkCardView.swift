import SwiftUI

// MARK: - DossierVelocitySparkCardView

/// A dossier card displaying a 12-week merged-PR velocity sparkline at full height.
struct DossierVelocitySparkCardView: View {

    // MARK: - Properties

    /// Weekly merged PR counts for the sparkline, ordered oldest to newest.
    let weeklyMerged: [Int]

    /// Number of PRs merged in the current week.
    let mergedThisWeek: Int

    /// Week-over-week delta versus the same week last year, or `nil` when prior-year data is unavailable.
    let mergedThisWeekDelta: Int?

    // MARK: - Body

    /// The view's content.
    var body: some View {
        DossierCardView {
            VStack(alignment: .leading, spacing: 8) {
                title
                if weeklyMerged.isEmpty {
                    emptyText
                } else {
                    BriefingSparkBarView(
                        values: normalized(weeklyMerged.map(Double.init)),
                        maxHeight: 100
                    )
                    footer
                }
            }
        }
    }

    // MARK: - Private

    /// The eyebrow label above the sparkline.
    private var title: some View {
        Text("Velocity (12w)")
            .font(BriefingFont.eyebrow)
            .textCase(.uppercase)
            .foregroundStyle(BriefingColor.ink3)
    }

    /// A placeholder shown when no spark data is available.
    private var emptyText: some View {
        Text("No data")
            .font(BriefingFont.body)
            .foregroundStyle(BriefingColor.ink3)
    }

    /// The "X this week / ±N vs yr ago" line below the sparkline.
    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(mergedThisWeek)")
                .font(BriefingFont.kpiSupporting)
                .foregroundStyle(BriefingColor.ink)
            Text("this week")
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
            if let delta = mergedThisWeekDelta, delta != 0 {
                Text(delta > 0 ? "+\(delta) vs yr ago" : "\(delta) vs yr ago")
                    .font(BriefingFont.meta)
                    .foregroundStyle(delta > 0 ? BriefingColor.green : BriefingColor.red)
            }
        }
    }

    /// Returns `0.0`–`1.0` normalized values relative to their peak.
    private func normalized(_ values: [Double]) -> [Double] {
        guard let peak = values.max(), peak > 0 else { return values.map { _ in 0 } }
        return values.map { $0 / peak }
    }
}

// MARK: - Preview

#Preview {
    DossierVelocitySparkCardView(
        weeklyMerged: [12, 18, 14, 22, 9, 17, 25, 21, 19, 28, 24, 16, 22, 27, 30, 24],
        mergedThisWeek: 24,
        mergedThisWeekDelta: 6
    )
    .padding()
    .background(BriefingColor.paper)
}
