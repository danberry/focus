import SwiftUI

// MARK: - BriefingSecuritySection

/// The "Security Debt" section — open alerts grouped by source.
///
/// Renders a section header above one full-width KPI card per security bucket
/// (Dependabot, Code Scanning, Secrets). Buckets with critical alerts use the
/// red tone.
struct BriefingSecuritySection: View {

    // MARK: - Properties

    /// The "Security Debt" section payload.
    let security: BriefingSecurity

    /// Optional closure invoked when the section header's "Triage all" action is tapped.
    var onTriage: (() -> Void)? = nil

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: BriefingLayout.sectionGap) {

            // MARK: Section header
            SectionHeaderView(
                number: "03",
                label: "Security Debt",
                verdict: security.verdict,
                actionLabel: "Triage all →",
                onAction: onTriage
            )

            // MARK: Security buckets
            HStack(spacing: 10) {
                ForEach(Array(security.buckets.enumerated()), id: \.offset) { _, bucket in
                    KPICardView(
                        title: bucket.name,
                        value: "\(bucket.open)",
                        deltaLabel: deltaLabel(for: bucket),
                        tone: bucket.critical > 0 ? .red : .neutral
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, BriefingLayout.gutter)
    }

    // MARK: - Helpers

    /// Returns the supporting delta line for a security bucket.
    ///
    /// Combines the week-over-week delta (when nonzero) with a critical-count
    /// suffix. Returns `nil` only when both are absent.
    private func deltaLabel(for bucket: BriefingSecurityBucket) -> String? {
        let deltaString: String? = {
            guard bucket.delta != 0 else { return nil }
            return bucket.delta > 0 ? "+\(bucket.delta)" : "\(bucket.delta)"
        }()

        switch (deltaString, bucket.critical > 0) {
        case let (delta?, true):
            return "\(delta) · \(bucket.critical) critical"
        case let (delta?, false):
            return delta
        case (nil, true):
            return "\(bucket.critical) critical"
        case (nil, false):
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    BriefingSecuritySection(security: Briefing.placeholder.security)
        .padding(.vertical)
}
