import SwiftUI

// MARK: - ShippingKPICardView

/// The Shipping KPI card shown in the briefing KPI strip.
///
/// Displays the weekly merged-PR total with an optional week-over-week delta
/// percentage, a subtitle line, and a 7-day bar sparkline where the peak day
/// is highlighted in green.
struct ShippingKPICardView: View {

    // MARK: - Properties

    let shipping: BriefingKPIShipping

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Velocity")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(.gray700)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(shipping.value)")
                    .font(BriefingFont.kpiHero)

                if let deltaPct {
                    Text(deltaPct)
                        .font(.system(size: 34, weight: .semibold))
                }
            }
            .foregroundStyle(.white)

            if let subtitle {
                Text(subtitle)
                    .font(BriefingFont.meta)
                    .foregroundStyle(.gray700)
            }

            BriefingSparkBarView(values: normalizedSpark)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private var normalizedSpark: [Double] {
        let counts = shipping.dailyCounts
        guard let peak = counts.max(), peak > 0 else { return counts.map { _ in 0.0 } }
        return counts.map { Double($0) / Double(peak) }
    }

    private var deltaPct: String? {
        guard let prior = shipping.priorWeekValue, prior > 0 else { return nil }
        let pct = Int(round(Double(shipping.value - prior) / Double(prior) * 100))
        return pct >= 0 ? "↑" : "↓"
    }

    private var subtitle: String? {
        guard let prior = shipping.priorWeekValue else { return nil }
        return "PRs merged"
    }
}

// MARK: - Preview

#Preview {
    ShippingKPICardView(
        shipping: BriefingKPIShipping(
            value: 73,
            dailyCounts: [8, 12, 9, 15, 11, 14, 4],
            priorWeekValue: 62
        )
    )
    .padding()
}
