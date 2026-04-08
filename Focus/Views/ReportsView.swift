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
            }
            .listStyle(.plain)
            .navigationTitle("Reports")
        }
    }
}

#Preview {
    ReportsView()
}
