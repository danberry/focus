import SwiftUI

// MARK: - ReviewLoadKPICardView

/// Displays the distribution of code review work across team members for the current week.
struct ReviewLoadKPICardView: View {

    // MARK: - Properties

    /// The review load data to render.
    let kpi: BriefingKPIReviewLoad

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Review Load")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(.gray700)

            Text("\(kpi.reviewers.count)")
                .font(BriefingFont.kpiHero)
                .foregroundStyle(.white)

            Text("reviewers active this week")
                .font(BriefingFont.meta)
                .foregroundStyle(.gray700)

            ReviewerBarChart(reviewers: kpi.reviewers)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
}

// MARK: - ReviewerBarChart

/// A horizontal bar chart showing each reviewer's relative review volume with a login label.
private struct ReviewerBarChart: View {

    // MARK: - Properties

    /// Reviewers to display, expected sorted descending by `normalizedCount`.
    let reviewers: [(login: String, normalizedCount: Double)]

    private let barMaxHeight: CGFloat = 20

    // MARK: - Body

    /// The view's content.
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(reviewers.prefix(7).enumerated()), id: \.offset) { _, reviewer in
                ReviewerBarColumn(reviewer: reviewer, barMaxHeight: barMaxHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }
}

// MARK: - ReviewerBarColumn

/// A single bar plus login label for one reviewer.
private struct ReviewerBarColumn: View {

    // MARK: - Properties

    /// The reviewer data to display.
    let reviewer: (login: String, normalizedCount: Double)

    /// The maximum pixel height a bar can reach (corresponds to `normalizedCount == 1.0`).
    let barMaxHeight: CGFloat

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(reviewer.normalizedCount >= 1.0 ? Color.customGreen : Color.gray600)
                .frame(height: max(1, reviewer.normalizedCount * barMaxHeight))

            Text(reviewer.login)
                .font(.system(size: 7, weight: .regular))
                .foregroundStyle(.gray700)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ReviewLoadKPICardView(
        kpi: BriefingKPIReviewLoad(
            reviewers: [
                (login: "alice", normalizedCount: 1.0),
                (login: "bob", normalizedCount: 0.75),
                (login: "carol", normalizedCount: 0.60),
                (login: "dave", normalizedCount: 0.45),
                (login: "eve", normalizedCount: 0.30),
                (login: "frank", normalizedCount: 0.20),
                (login: "grace", normalizedCount: 0.10),
            ]
        )
    )
    .padding()
    .background(Color.black)
}
