import SwiftUI

// MARK: - BriefingShippedSection

/// The "What Shipped" section — merged PR counts by repo and top contributors.
///
/// Renders a section header, a horizontal-bar chart of per-repo merge counts,
/// and a contributor leaderboard with avatar initials.
struct BriefingShippedSection: View {

    // MARK: - Properties

    /// The "What Shipped" section payload.
    let shipped: BriefingShipped

    /// Optional closure invoked when the section header's "See all" action is tapped.
    var onSeeAll: (() -> Void)? = nil

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: BriefingLayout.sectionGap) {

            // MARK: Section header
            SectionHeaderView(
                number: "01",
                verdict: shipped.verdict,
                summary: "Summary placeholder",
                actionLabel: "See all →",
                onAction: onSeeAll
            )

            // MARK: PRs merged + Top contributors (side by side)
            HStack(alignment: .top, spacing: 16) {

                // MARK: PRs merged by repo
                VStack(alignment: .leading, spacing: 0) {
                    Text("PRs merged by repo")
                        .font(BriefingFont.eyebrow)
                        .textCase(.uppercase)
                        .foregroundStyle(BriefingColor.ink4)
                        .padding(.bottom, 6)

                    VStack(spacing: 6) {
                        ForEach(Array(shipped.repos.prefix(6).enumerated()), id: \.offset) { _, repo in
                            RepoBarRow(repo: repo, maxCount: maxRepoCount)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: Top contributors
                VStack(alignment: .leading, spacing: 0) {
                    Text("Top contributors")
                        .font(BriefingFont.eyebrow)
                        .textCase(.uppercase)
                        .foregroundStyle(BriefingColor.ink4)
                        .padding(.bottom, 6)

                    VStack(spacing: 6) {
                        ForEach(Array(shipped.contributors.enumerated()), id: \.offset) { _, contributor in
                            ContributorRow(contributor: contributor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, BriefingLayout.gutter)
    }

    // MARK: - Helpers

    /// The largest per-repo merge count, used as the bar-width denominator.
    private var maxRepoCount: Int {
        shipped.repos.prefix(6).map(\.count).max() ?? 1
    }
}

// MARK: - RepoBarRow

/// A single merged-PR bar row inside the "What Shipped" section.
private struct RepoBarRow: View {

    // MARK: - Properties

    /// The per-repo count to render.
    let repo: BriefingRepoCount

    /// The largest count across all repos in the section, used to normalize bar width.
    let maxCount: Int

    // MARK: - Body

    /// The view's content.
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(repo.flag ? BriefingColor.blue : BriefingColor.ink4)
                .frame(width: barWidth, height: 8)

            Text(repo.name)
                .font(BriefingFont.body)
                .foregroundStyle(BriefingColor.ink)

            Spacer()

            Text("\(repo.count)")
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
        }
    }

    // MARK: - Helpers

    /// The proportional width of the bar in points, capped at 120.
    private var barWidth: CGFloat {
        let denominator = max(1, maxCount)
        return CGFloat(repo.count) / CGFloat(denominator) * 120
    }
}

// MARK: - ContributorRow

/// A single contributor row inside the "What Shipped" section.
private struct ContributorRow: View {

    // MARK: - Properties

    /// The contributor row data to render.
    let contributor: BriefingContributor

    // MARK: - Body

    /// The view's content.
    var body: some View {
        HStack(spacing: 8) {
            BriefingAvatarView(initials: contributor.initials, size: 28)

            Text(contributor.name)
                .font(BriefingFont.body)
                .foregroundStyle(BriefingColor.ink)

            Spacer()

            Text("\(contributor.count) PRs")
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
        }
    }
}

// MARK: - Preview

#Preview {
    BriefingShippedSection(shipped: Briefing.placeholder.shipped)
        .padding(.vertical)
}
