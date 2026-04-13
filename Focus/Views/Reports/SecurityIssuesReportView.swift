import SwiftUI
import SwiftData
import Charts

// MARK: - SecurityIssuesReportView

/// Displays a breakdown of open security alerts across all saved repositories.
struct SecurityIssuesReportView: View {

    // MARK: - Properties

    /// The saved repositories to aggregate security alert counts from.
    @Query(sort: \SavedRepository.displayName) private var repositories: [SavedRepository]

    /// The security alert categories with per-repository breakdowns, filtered to non-zero totals.
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

    /// The total open alert count across all repositories and alert types.
    private var totalCount: Int {
        repositories.reduce(0) { $0 + $1.totalSecurityAlerts }
    }

    /// The number of repositories with at least one open security alert.
    private var reposWithAlerts: Int {
        repositories.count(where: { $0.totalSecurityAlerts > 0 })
    }

    // MARK: - Body

    /// The view's content.
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

// MARK: - SecurityCategory

/// A named alert category with a total count and per-repository breakdown rows.
private struct SecurityCategory: Identifiable {

    // MARK: - Properties

    /// A stable identifier for use in `ForEach`.
    let id = UUID()

    /// The display name of the alert category (e.g., "Dependabot").
    let name: String

    /// The total open alert count across all repositories in this category.
    let count: Int

    /// The per-repository rows, sorted by descending alert count.
    let repoRows: [SecurityRepoRow]
}

// MARK: - SecurityRepoRow

/// A single row pairing a repository name with its alert count for a category.
private struct SecurityRepoRow: Identifiable {

    // MARK: - Properties

    /// A stable identifier for use in `ForEach`.
    let id = UUID()

    /// The display name of the repository.
    let name: String

    /// The number of open alerts for this repository in the parent category.
    let count: Int
}
