import SwiftUI

// MARK: - ReportsView

struct ReportsView: View {
    var body: some View {
        NavigationStack {
            List {
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
                    MemberDisciplineReportView()
                } label: {
                    LabeledContent {
                    } label: {
                        Text("Members by Discipline")
                        Text("Breakdown of members across each discipline")
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
