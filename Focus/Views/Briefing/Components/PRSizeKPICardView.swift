import SwiftUI

// MARK: - PRSizeKPICardView

/// The PR Size KPI card shown in the briefing KPI strip.
///
/// Displays the median lines changed per merged PR for the week with an optional
/// week-over-week delta arrow, a subtitle line, and a 7-day bar sparkline where
/// the peak day is highlighted.
struct PRSizeKPICardView: View {

    // MARK: - Properties

    let prSize: BriefingKPIPRSize

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PR Size")
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

            Text("median lines/PR")
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
        let v = prSize.value
        if v >= 1_000 { return "\(v / 1_000)k" }
        return "\(v)"
    }

    private var normalizedSpark: [Double] {
        let medians = prSize.dailyMedians
        guard let peak = medians.max(), peak > 0 else { return medians.map { _ in 0.0 } }
        return medians.map { Double($0) / Double(peak) }
    }

    private var delta: String? {
        guard let prior = prSize.priorWeekValue, prior > 0 else { return nil }
        let diff = prSize.value - prior
        if diff == 0 { return "→" }
        return diff > 0 ? "↑" : "↓"
    }
}

// MARK: - Preview

#Preview {
    PRSizeKPICardView(
        prSize: BriefingKPIPRSize(
            value: 342,
            dailyMedians: [210, 450, 380, 290, 510, 342, 180],
            priorWeekValue: 295
        )
    )
    .padding()
}
