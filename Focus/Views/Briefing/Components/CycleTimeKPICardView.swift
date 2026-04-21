import SwiftUI

// MARK: - CycleTimeKPICardView

/// The Cycle Time KPI card shown in the briefing KPI strip.
///
/// Displays the median open-to-merge cycle time for the week with an optional
/// week-over-week delta arrow, a subtitle line, and a 7-day bar sparkline where
/// the peak day is highlighted.
struct CycleTimeKPICardView: View {

    // MARK: - Properties

    let cycleTime: BriefingKPIMedianMerge

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cycle Time")
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

            Text("open → merge")
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
        let h = cycleTime.value
        if h < 24 { return "\(h)h" }
        let days = Int((Double(h) / 24).rounded())
        return "\(days)d"
    }

    private var normalizedSpark: [Double] {
        let medians = cycleTime.dailyMedians
        guard let peak = medians.max(), peak > 0 else { return medians.map { _ in 0.0 } }
        return medians.map { Double($0) / Double(peak) }
    }

    private var delta: String? {
        guard let prior = cycleTime.priorWeekValue, prior > 0 else { return nil }
        let diff = cycleTime.value - prior
        if diff == 0 { return "→" }
        // Lower cycle time is better — flip arrow direction.
        return diff < 0 ? "↓" : "↑"
    }
}

// MARK: - Preview

#Preview {
    CycleTimeKPICardView(
        cycleTime: BriefingKPIMedianMerge(
            value: 18,
            dailyMedians: [22, 14, 18, 31, 12, 20, 16],
            priorWeekValue: 24
        )
    )
    .padding()
}
