import SwiftUI

// MARK: - SecurityDebtKPICardView

/// The Security Debt KPI card shown in the briefing KPI strip.
///
/// Displays the total open security alert count with an optional week-over-week
/// delta percentage, a subtitle showing the critical count, and a 7-day bar
/// sparkline where each bar represents the running open-alert total for that day.
struct SecurityDebtKPICardView: View {

    // MARK: - Properties

    let security: BriefingKPISecurity

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Security Issues")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(.gray700)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(security.value)")
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

            BriefingSparkBarView(
                values: normalizedSpark,
                highlightColor: .customYellow
            )
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private var normalizedSpark: [Double] {
        let totals = security.dailyOpenTotals
        guard let peak = totals.max(), peak > 0 else { return totals.map { _ in 0.0 } }
        return totals.map { Double($0) / Double(peak) }
    }

    private var deltaPct: String? {
        guard let prior = security.priorWeekTotal, prior > 0 else { return nil }
        let pct = Int(round(Double(security.value - prior) / Double(prior) * 100))
        return pct >= 0 ? "↑" : "↓"
    }

    private var subtitle: String? {
        guard security.critical > 0 else { return nil }
        return "\(security.critical) critical"
    }
}

// MARK: - Preview

#Preview {
    SecurityDebtKPICardView(
        security: BriefingKPISecurity(
            value: 48,
            critical: 12,
            dailyOpenTotals: [38, 41, 43, 45, 46, 47, 48],
            priorWeekTotal: 38
        )
    )
    .padding()
}
