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
                color: .accentedOrange,
                repoRows: repositories
                    .filter { $0.dependabotAlerts > 0 }
                    .map { SecurityRepoRow(name: $0.displayName, count: $0.dependabotAlerts) }
            ),
            SecurityCategory(
                name: "Code Scanning",
                count: repositories.reduce(0) { $0 + $1.codeScanningAlerts },
                color: .accentedBlue,
                repoRows: repositories
                    .filter { $0.codeScanningAlerts > 0 }
                    .map { SecurityRepoRow(name: $0.displayName, count: $0.codeScanningAlerts) }
            ),
            SecurityCategory(
                name: "Secret Scanning",
                count: repositories.reduce(0) { $0 + $1.secretScanningAlerts },
                color: .accentedRed,
                repoRows: repositories
                    .filter { $0.secretScanningAlerts > 0 }
                    .map { SecurityRepoRow(name: $0.displayName, count: $0.secretScanningAlerts) }
            ),
        ].filter { $0.count > 0 }
    }

    private var totalCount: Int {
        repositories.reduce(0) { $0 + $1.totalSecurityAlerts }
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
                    Section {
                        SecurityHeroRow(totalCount: totalCount)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listSectionSpacing(18)
                    Section {
                        SecurityBreakdownChartView(categories: categories)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                    ForEach(categories) { category in
                        Section {
                            ForEach(category.repoRows) { row in
                                LabeledContent(row.name) {
                                    Text("\(row.count)")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        } header: {
                            HStack {
                                Text(category.name)
                                Spacer()
                                Text("\(category.count)")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Security Issues")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supporting Types

private struct SecurityCategory: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let color: Color
    let repoRows: [SecurityRepoRow]
}

private struct SecurityRepoRow: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

// MARK: - SecurityHeroRow

private struct SecurityHeroRow: View {
    let totalCount: Int

    var body: some View {
        LabeledContent {} label: {
            Text("\(totalCount)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(totalCount == 1 ? "open security alert" : "open security alerts")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(1.2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 26))
    }
}

// MARK: - SecurityBreakdownChartView

private struct SecurityBreakdownChartView: View {
    let categories: [SecurityCategory]

    private var total: Int { categories.reduce(0) { $0 + $1.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Chart(categories) { category in
                    SectorMark(
                        angle: .value("Issues", category.count),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", category.name))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale(
                    domain: categories.map(\.name),
                    range: categories.map(\.color)
                )
                .chartLegend(.hidden)
                .frame(height: 180)

                VStack(spacing: 2) {
                    Text("\(total)")
                        .font(.title2.bold())
                    Text(total == 1 ? "alert" : "alerts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Legend
            VStack(alignment: .leading, spacing: 6) {
                ForEach(categories) { category in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(category.color)
                            .frame(width: 12, height: 12)
                        Text(category.name)
                            .font(.caption)
                        Spacer()
                        Text("\(category.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
