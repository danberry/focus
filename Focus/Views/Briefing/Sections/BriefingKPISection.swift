import SwiftUI

// MARK: - BriefingKPISection

/// The KPI strip shown between the hero verdict and the first editorial section.
///
/// Composes two hero KPI cards (Shipping, Security Debt) above a 2×2 grid of
/// supporting KPI cards (Idle, Review Median, CI Pass, Releases).
struct BriefingKPISection: View {

    // MARK: - Properties

    /// The KPI totals payload to render.
    let kpis: BriefingKPIs

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Grid(horizontalSpacing: 0) {
            GridRow(alignment: .top) {
                ShippingKPICardView(shipping: kpis.shipping)
                    .gridCellColumns(2)

                divider

                SecurityDebtKPICardView(security: kpis.security)
                    .gridCellColumns(2)

                divider

                KPICardView(
                    title: "Idle",
                    value: "\(kpis.idle.value)",
                    inlineDeltaLabel: idleDeltaLabel,
                    deltaLabel: kpis.idle.value > 0 ? "7d+" : nil
                )
                
                divider

                if let cycleTime = kpis.medianMerge {
                    CycleTimeKPICardView(cycleTime: cycleTime)
                } else {
                    KPICardView(title: "Cycle Time", value: "—")
                }

                divider

                KPICardView(
                    title: "CI Pass",
                    value: kpis.ciPass.map { "\($0.value)%" } ?? "—",
                    inlineDeltaLabel: ciPassDeltaLabel,
                    deltaLabel: kpis.ciPass != nil ? "target 95%" : nil
                )
                
                divider

                KPICardView(
                    title: "Releases",
                    value: kpis.releases.map { "\($0.value)" } ?? "—",
                    inlineDeltaLabel: releasesDeltaLabel
                )
            }
        }
    }
    
    private var divider: some View {
        Divider()
            .frame(maxWidth: 1, maxHeight:.infinity)
            .background(.gray400)
    }

    // MARK: - Helpers

    /// Returns a week-over-week delta label for the CI pass rate, or `nil` when unavailable.
    private var ciPassDeltaLabel: String? {
        guard let ci = kpis.ciPass, let prior = ci.priorWeekValue else { return nil }
        let delta = ci.value - prior
        if delta == 0 { return "→" }
        return delta > 0 ? "↑" : "↓"
    }

    /// Returns a week-over-week delta label for releases, or `nil` when unavailable.
    private var releasesDeltaLabel: String? {
        guard let r = kpis.releases, let prior = r.priorWeekValue else { return nil }
        let delta = r.value - prior
        if delta == 0 { return "→" }
        return delta > 0 ? "↑" : "↓"
    }

    /// Returns the formatted delta label for the idle KPI, or `nil` when the delta is zero.
    private var idleDeltaLabel: String? {
        let delta = kpis.idle.delta
        if delta > 0 { return "↑" }
        if delta < 0 { return "↓" }
        return kpis.idle.value > 0 ? "→" : nil
    }
}

// MARK: - Preview

#Preview {
    BriefingKPISection(kpis: Briefing.placeholder.kpis)
        .padding(.vertical)
}
