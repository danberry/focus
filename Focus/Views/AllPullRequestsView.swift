import SwiftUI

// MARK: - AllPullRequestsView

struct AllPullRequestsView: View {
    let pullRequests: [OpenPullRequest]

    var body: some View {
        List {
            ForEach(pullRequests) { pr in
                NavigationLink(destination: PullRequestDetailView(pullRequest: pr)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pr.title)
                        Text(daysOpenLabel(pr.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Open Pull Requests")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Private

    private func daysOpenLabel(_ createdAt: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: createdAt, to: .now).day ?? 0
        return days == 1 ? "1 day open" : "\(days) days open"
    }
}
