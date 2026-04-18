import SwiftUI

// MARK: - BriefingKPISection

/// The KPI strip shown between the hero verdict and the first editorial section.
///
/// Composes two hero KPI cards (Shipping, Security Debt) above a 2×2 grid of
/// supporting KPI cards (Idle, Review Median, CI Pass, Deploys).
struct BriefingKPISection: View {

    // MARK: - Properties

    /// The KPI totals payload to render.
    let kpis: BriefingKPIs

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(spacing: 12) {

            // MARK: Hero row
            HStack(spacing: 12) {
                KPICardView(
                    title: "Shipping",
                    value: "\(kpis.shipping.value)",
                    deltaLabel: nil,
                    spark: kpis.shipping.spark,
                    tone: .neutral,
                    isHero: true
                )
                .frame(maxWidth: .infinity)

                KPICardView(
                    title: "Security Debt",
                    value: "\(kpis.security.value)",
                    deltaLabel: kpis.security.critical > 0 ? "\(kpis.security.critical) critical" : nil,
                    spark: kpis.security.spark,
                    tone: .red,
                    isHero: true
                )
                .frame(maxWidth: .infinity)
            }

            // MARK: Supporting grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                KPICardView(
                    title: "Idle",
                    value: "\(kpis.idle.value)",
                    deltaLabel: idleDeltaLabel
                )

                KPICardView(
                    title: "Review Median",
                    value: kpis.reviewMedianHours.map { "\($0)h" } ?? "—"
                )

                KPICardView(
                    title: "CI Pass",
                    value: kpis.ciPassPct.map { "\($0)%" } ?? "—"
                )

                KPICardView(
                    title: "Deploys",
                    value: kpis.deploys.map { "\($0)" } ?? "—"
                )
            }
        }
        .padding(.horizontal, BriefingLayout.gutter)
    }

    // MARK: - Helpers

    /// Returns the formatted delta label for the idle KPI, or `nil` when the delta is zero.
    private var idleDeltaLabel: String? {
        let delta = kpis.idle.delta
        guard delta != 0 else { return nil }
        return delta > 0 ? "+\(delta)" : "\(delta)"
    }
}

// MARK: - Preview

#Preview {
    BriefingKPISection(kpis: Briefing.placeholder.kpis)
        .padding(.vertical)
}
