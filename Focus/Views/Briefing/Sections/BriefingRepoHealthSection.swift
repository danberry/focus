import SwiftUI

// MARK: - BriefingRepoHealthSection

/// The "Repo Health" section — open security alerts ranked by repository.
///
/// Renders a section header above a divider-separated table of repo rows, each
/// showing the repo name, total open alert count, and a normalized score bar.
struct BriefingRepoHealthSection: View {

    // MARK: - Properties

    /// The per-repository health rows to render.
    let repoHealth: [BriefingRepoHealth]

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: BriefingLayout.sectionGap) {

            // MARK: Section header
            SectionHeaderView(
                number: "04",
                label: "Repo Health",
                verdict: "Open security alerts by repository."
            )

            // MARK: Repo health table
            VStack(spacing: 0) {
                ForEach(Array(repoHealth.enumerated()), id: \.offset) { index, repo in
                    RepoHealthRow(repo: repo)

                    if index < repoHealth.count - 1 {
                        Divider()
                            .background(BriefingColor.rule2)
                    }
                }
            }
        }
        .padding(.horizontal, BriefingLayout.gutter)
    }
}

// MARK: - RepoHealthRow

/// A single repo row inside the "Repo Health" section table.
private struct RepoHealthRow: View {

    // MARK: - Properties

    /// The per-repository health payload to render.
    let repo: BriefingRepoHealth

    // MARK: - Body

    /// The view's content.
    var body: some View {
        HStack(spacing: 12) {
            Text(repo.name)
                .font(BriefingFont.body)
                .foregroundStyle(BriefingColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(repo.openAlerts)")
                .font(BriefingFont.meta)
                .monospacedDigit()
                .foregroundStyle(BriefingColor.ink3)
                .frame(width: 28, alignment: .trailing)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(BriefingColor.paper3)
                    .frame(width: 60, height: 6)

                RoundedRectangle(cornerRadius: 2)
                    .fill(repo.urgent ? BriefingColor.red : BriefingColor.ink4)
                    .frame(width: fillWidth, height: 6)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    /// The proportional width of the score-bar fill, in points.
    private var fillWidth: CGFloat {
        let clamped = min(max(repo.score, 0), 100)
        return CGFloat(clamped) / 100 * 60
    }
}

// MARK: - Preview

#Preview {
    BriefingRepoHealthSection(repoHealth: Briefing.placeholder.repoHealth)
        .padding(.vertical)
}
