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
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(maxWidth: 1, maxHeight:.infinity)
                    .background(BriefingColor.rule)

                SecurityDebtKPICardView(security: kpis.security)
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(maxWidth: 1, maxHeight:.infinity)
                    .background(BriefingColor.rule)
                
                KPICardView(
                    title: "Idle",
                    value: "\(kpis.idle.value)",
                    inlineDeltaLabel: idleDeltaLabel,
                    deltaLabel: kpis.idle.value > 0 ? "7d+" : nil
                )
                
                Divider()
                    .frame(maxWidth: 1, maxHeight:.infinity)
                    .background(BriefingColor.rule)

                KPICardView(
                    title: "Median Merge Time",
                    value: kpis.medianMerge.map { "\($0.value)h" } ?? "—",
                    inlineDeltaLabel: medianMergeDeltaLabel,
                    deltaLabel: kpis.medianMerge != nil ? "target 24h" : nil
                )
                
                Divider()
                    .frame(maxWidth: 1, maxHeight:.infinity)
                    .background(BriefingColor.rule)

                KPICardView(
                    title: "CI Pass",
                    value: kpis.ciPass.map { "\($0.value)%" } ?? "—",
                    inlineDeltaLabel: ciPassDeltaLabel,
                    deltaLabel: kpis.ciPass != nil ? "target 95%" : nil
                )
                
                Divider()
                    .frame(maxWidth: 1, maxHeight:.infinity)
                    .background(BriefingColor.rule)

                KPICardView(
                    title: "Releases",
                    value: kpis.releases.map { "\($0.value)" } ?? "—",
                    inlineDeltaLabel: releasesDeltaLabel
                )
            }
        }
    }

    // MARK: - Helpers

    /// Returns a week-over-week delta label for the median merge time, or `nil` when unavailable.
    private var medianMergeDeltaLabel: String? {
        guard let merge = kpis.medianMerge, let prior = merge.priorWeekValue else { return nil }
        let delta = merge.value - prior
        if delta == 0 { return "→" }
        return delta > 0 ? "↑ \(delta)h" : "↓ \(-delta)h"
    }

    /// Returns a week-over-week delta label for the CI pass rate, or `nil` when unavailable.
    private var ciPassDeltaLabel: String? {
        guard let ci = kpis.ciPass, let prior = ci.priorWeekValue else { return nil }
        let delta = ci.value - prior
        if delta == 0 { return "→" }
        return delta > 0 ? "+\(delta)pp" : "\(delta)pp"
    }

    /// Returns a week-over-week delta label for releases, or `nil` when unavailable.
    private var releasesDeltaLabel: String? {
        guard let r = kpis.releases, let prior = r.priorWeekValue else { return nil }
        let delta = r.value - prior
        if delta == 0 { return "→" }
        return delta > 0 ? "↑ \(delta)" : "↓ \(-delta)"
    }

    /// Returns the formatted delta label for the idle KPI, or `nil` when the delta is zero.
    private var idleDeltaLabel: String? {
        let delta = kpis.idle.delta
        if delta > 0 { return "↑ \(delta)" }
        if delta < 0 { return "↓ \(-delta)" }
        return kpis.idle.value > 0 ? "→" : nil
    }
}

// MARK: - Preview

#Preview {
    BriefingKPISection(kpis: Briefing.placeholder.kpis)
        .padding(.vertical)
}
