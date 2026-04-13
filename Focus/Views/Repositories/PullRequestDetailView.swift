import SwiftUI

// MARK: - PullRequestDetailView

/// Displays detail information for a single open pull request.
struct PullRequestDetailView: View {

    // MARK: - Properties

    /// The pull request whose detail data this view displays.
    let pullRequest: OpenPullRequest

    // MARK: - Body

    /// The view's content.
    var body: some View {
        List {
            // MARK: Overview

            Section("Overview") {
                LabeledContent("Title", value: pullRequest.title)
                LabeledContent("Author", value: pullRequest.authorLogin)
                LabeledContent("PR Number", value: "#\(pullRequest.number)")
            }

            // MARK: Timeline

            Section("Timeline") {
                LabeledContent("Opened", value: pullRequest.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Days Open", value: "\(daysOpen)")
            }

            // MARK: Actions

            Section {
                if let url = URL(string: pullRequest.url) {
                    Link(destination: url) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("#\(pullRequest.number)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    /// The number of days the pull request has been open.
    private var daysOpen: Int {
        Calendar.current.dateComponents([.day], from: pullRequest.createdAt, to: .now).day ?? 0
    }
}
