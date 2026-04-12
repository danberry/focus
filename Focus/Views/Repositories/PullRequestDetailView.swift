import SwiftUI

// MARK: - PullRequestDetailView

struct PullRequestDetailView: View {
    let pullRequest: OpenPullRequest

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

    // MARK: - Private

    private var daysOpen: Int {
        Calendar.current.dateComponents([.day], from: pullRequest.createdAt, to: .now).day ?? 0
    }
}
