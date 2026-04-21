import SwiftUI

// MARK: - ReportsView

/// Displays the available reports for merged pull requests, team composition, and security.
struct ReportsView: View {

    // MARK: - Body

    /// The view's content.
    var body: some View {
        NavigationStack {
            List {
                // MARK: Merged PRs
                NavigationLink {
                    MergedPRsTodayView()
                } label: {
                    LabeledContent {
                    } label: {
                        Text("Merged PRs Today")
                        Text("PRs merged across your saved repos today")
                    }
                }
                NavigationLink {
                    MergedPRsYesterdayView()
                } label: {
                    LabeledContent {
                    } label: {
                        Text("Merged PRs Yesterday")
                        Text("PRs merged across your saved repos yesterday")
                    }
                }
                NavigationLink {
                    MergedPRsThisWeekView()
                } label: {
                    LabeledContent {
                    } label: {
                        Text("Merged PRs This Week")
                        Text("PRs merged across your saved repos this week")
                    }
                }
                // MARK: Velocity
                NavigationLink {
                    IssueVelocityReportView()
                } label: {
                    LabeledContent {
                    } label: {
                        Text("Issue Velocity")
                        Text("Merged PR velocity across your saved repos by period")
                    }
                }
                // MARK: Members
                NavigationLink {
                    MemberDisciplineReportView()
                } label: {
                    LabeledContent {
                    } label: {
                        Text("Members by Discipline")
                        Text("Breakdown of members across each discipline")
                    }
                }
                // MARK: Security
                NavigationLink {
                    SecurityIssuesReportView()
                } label: {
                    LabeledContent {
                    } label: {
                        Text("Security Issues")
                        Text("Total alerts by category across your saved repos")
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Reports")
        }
    }
}

#Preview {
    ReportsView()
}
