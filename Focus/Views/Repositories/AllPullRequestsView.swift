import SwiftUI

// MARK: - AllPullRequestsView

/// Displays a full list of open pull requests for a repository.
struct AllPullRequestsView: View {

    // MARK: - Properties

    /// The pull requests to display.
    let pullRequests: [OpenPullRequest]

    // MARK: - Body

    /// The view's content.
    var body: some View {
        List {
            ForEach(pullRequests) { pr in
                NavigationLink(destination: PullRequestDetailView(pullRequest: pr)) {
                    LabeledContent {
                    } label: {
                        Text(pr.title)
                        Text(daysOpenLabel(pr.createdAt))
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Open Pull Requests")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    /// Returns a human-readable label for how long a pull request has been open.
    private func daysOpenLabel(_ createdAt: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: createdAt, to: .now).day ?? 0
        return days == 1 ? "1 day open" : "\(days) days open"
    }
}
