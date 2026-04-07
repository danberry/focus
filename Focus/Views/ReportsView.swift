import SwiftUI

// MARK: - ReportsView

struct ReportsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    MergedPRsYesterdayView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Merged PRs Yesterday")
                        Text("PRs merged across your saved repos yesterday")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Reports")
        }
    }
}

#Preview {
    ReportsView()
}
