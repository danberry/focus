import SwiftUI

// MARK: - SecurityDebtKPICardView

/// The Security Debt KPI card shown in the briefing KPI strip.
///
/// Displays the total open security alert count with an optional week-over-week
/// delta percentage, a subtitle showing the critical count, and a 7-day bar
/// sparkline where each bar represents new alerts created that day.
struct SecurityDebtKPICardView: View {

    // MARK: - Properties

    let security: BriefingKPISecurity

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Security Debt")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(BriefingColor.ink3)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(security.value)")
                    .font(BriefingFont.kpiHero)
                    .foregroundStyle(BriefingColor.ink)

                if let deltaPct {
                    Text(deltaPct)
                        .font(BriefingFont.meta)
                        .foregroundStyle(BriefingColor.ink)
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(BriefingFont.meta)
                    .foregroundStyle(BriefingColor.ink3)
            }

            BriefingSparkBarView(values: normalizedSpark)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var normalizedSpark: [Double] {
        let counts = security.dailyCounts
        guard let peak = counts.max(), peak > 0 else { return counts.map { _ in 0.0 } }
        return counts.map { Double($0) / Double(peak) }
    }

    private var deltaPct: String? {
        guard let prior = security.priorWeekTotal, prior > 0 else { return nil }
        let thisWeek = security.dailyCounts.reduce(0, +)
        let pct = Int(round(Double(thisWeek - prior) / Double(prior) * 100))
        return pct >= 0 ? "↑ \(pct)%" : "↓ \(-pct)%"
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
            dailyCounts: [2, 4, 3, 6, 5, 4, 1],
            priorWeekTotal: 20
        )
    )
    .padding()
}
