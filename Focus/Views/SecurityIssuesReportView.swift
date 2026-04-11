import SwiftUI
import SwiftData
import Charts

// MARK: - SecurityIssuesReportView

struct SecurityIssuesReportView: View {
    @Query(sort: \SavedRepository.displayName) private var repositories: [SavedRepository]

    private var categories: [SecurityCategory] {
        [
            SecurityCategory(
                name: "Dependabot",
                count: repositories.reduce(0) { $0 + $1.dependabotAlerts },
                repoRows: repositories
                    .filter { $0.dependabotAlerts > 0 }
                    .sorted(by: { $0.dependabotAlerts > $1.dependabotAlerts })
                    .map { SecurityRepoRow(name: $0.displayName, count: $0.dependabotAlerts) }
            ),
            SecurityCategory(
                name: "Code Scanning",
                count: repositories.reduce(0) { $0 + $1.codeScanningAlerts },
                repoRows: repositories
                    .filter { $0.codeScanningAlerts > 0 }
                    .sorted(by: { $0.codeScanningAlerts > $1.codeScanningAlerts })
                    .map { SecurityRepoRow(name: $0.displayName, count: $0.codeScanningAlerts) }
            ),
            SecurityCategory(
                name: "Secret Scanning",
                count: repositories.reduce(0) { $0 + $1.secretScanningAlerts },
                repoRows: repositories
                    .filter { $0.secretScanningAlerts > 0 }
                    .sorted(by: { $0.secretScanningAlerts > $1.secretScanningAlerts })
                    .map { SecurityRepoRow(name: $0.displayName, count: $0.secretScanningAlerts) }
            ),
        ].filter { $0.count > 0 }
    }

    private var totalCount: Int {
        repositories.reduce(0) { $0 + $1.totalSecurityAlerts }
    }
    
    private var reposWithAlerts: Int {
        repositories.count(where: { $0.totalSecurityAlerts > 0 })
    }

    var body: some View {
        Group {
            if repositories.isEmpty {
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "shield",
                    description: Text("Add repositories to see a security issues breakdown.")
                )
            } else if totalCount == 0 {
                ContentUnavailableView(
                    "No Security Issues",
                    systemImage: "checkmark.shield",
                    description: Text("No open security alerts found across your saved repositories.")
                )
            } else {
                List {
                    CardRow {
                        LabeledContent {} label: {
                            Text(totalCount, format: .number)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                            Text(totalCount == 1 ? "issue" : "issues")
                                .textCase(.uppercase)
                        }
                    }
                    
                    ForEach(categories) { category in
                        Section(category.name) {
                            ForEach(category.repoRows) { row in
                                LabeledContent(row.name) {
                                    Text(row.count, format: .number)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Security Issues")
        .navigationSubtitle("^[\(reposWithAlerts) repo](inflect: true)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supporting Types

private struct SecurityCategory: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let repoRows: [SecurityRepoRow]
}

private struct SecurityRepoRow: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}
