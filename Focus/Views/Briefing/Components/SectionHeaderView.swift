import SwiftUI

// MARK: - SectionHeaderView

/// The editorial-style header rendered above each briefing section.
///
/// Combines a numbered eyebrow, an optional right-aligned action, a serif
/// verdict, and an optional supporting evidence line. This view never paints
/// its own card background — it sits flat against the page surface.
struct SectionHeaderView: View {

    // MARK: - Properties

    /// The two-digit section number, e.g. `"01"`.
    let number: String

    /// The serif verdict sentence shown beneath the eyebrow row.
    let verdict: String

    /// Optional summary line shown below the verdict row.
    var summary: String? = nil

    /// Optional supporting evidence line shown beneath the verdict.
    var evidenceLine: String? = nil

    /// Optional label for the right-aligned action button.
    var actionLabel: String? = nil

    /// Optional action invoked when the right-aligned button is tapped.
    var onAction: (() -> Void)? = nil

    // MARK: - Body

    /// The view's content.
    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            Text("§ \(number)")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(BriefingColor.red)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 12) {
                Text(.init(verdict))
                    .font(BriefingFont.sectionVerdict)
                    .foregroundStyle(BriefingColor.ink)

                if let summary {
                    Text(summary)
                        .font(BriefingFont.meta)
                        .foregroundStyle(BriefingColor.ink3)
                }

                if let evidenceLine {
                    Text(evidenceLine)
                        .font(BriefingFont.meta)
                        .foregroundStyle(BriefingColor.ink3)
                }
            }

            Spacer()

            if let actionLabel, let onAction {
                Button(actionLabel, action: onAction)
                    .font(BriefingFont.eyebrow)
                    .foregroundStyle(BriefingColor.ink3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    SectionHeaderView(
        number: "01",
        verdict: "Shipping held steady. payments-api led the week.",
        evidenceLine: "142 PRs merged across 5 repos"
    )
    .padding()
}
