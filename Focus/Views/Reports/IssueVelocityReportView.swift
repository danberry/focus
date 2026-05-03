import SwiftUI
import SwiftData

// MARK: - IssueVelocityReportView

/// Displays merged PR velocity across all saved repositories for a selected time period.
///
/// Reads from persisted ``RepositoryVelocity`` records — no network call is made.
/// The period picker in the toolbar controls which window is shown.
struct IssueVelocityReportView: View {

    // MARK: - Properties

    /// All saved repositories, sorted alphabetically by display name.
    @Query(sort: \SavedRepository.displayName) private var repositories: [SavedRepository]

    /// The time period currently selected in the toolbar picker.
    @State private var selectedPeriod: VelocityPeriod = .sevenDays

    /// Per-repository velocity rows for the selected period, sorted by current count descending.
    private var repoRows: [VelocityRow] {
        repositories.compactMap { repo in
            guard let record = (repo.velocityMetrics ?? []).first(where: { $0.periodType == selectedPeriod.rawValue }) else {
                return nil
            }
            return VelocityRow(
                name: repo.displayName,
                comparison: record.comparison
            )
        }
        .sorted { $0.comparison.current > $1.comparison.current }
    }

    /// The total merged PR count across all repositories for the selected period.
    private var totalCount: Int {
        repoRows.reduce(0) { $0 + $1.comparison.current }
    }

    /// Whether any repository has velocity data for the selected period.
    private var hasData: Bool { !repoRows.isEmpty }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Group {
            if repositories.isEmpty {
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "arrow.trianglehead.branch",
                    description: Text("Add repositories to see velocity metrics.")
                )
            } else if !hasData {
                ContentUnavailableView(
                    "No Velocity Data",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text("Velocity data will appear after the next sync.")
                )
            } else {
                List {
                    // MARK: Hero
                    CardRow {
                        LabeledContent {} label: {
                            Text(totalCount, format: .number)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                            Text(selectedPeriod.displayLabel)
                                .textCase(.uppercase)
                        }
                    }

                    // MARK: Repos
                    ForEach(repoRows) { row in
                        VelocityRepoRow(row: row)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Issue Velocity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(VelocityPeriod.allCases, id: \.self) { period in
                        Button {
                            selectedPeriod = period
                        } label: {
                            Label(period.rawValue, systemImage: selectedPeriod == period ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(selectedPeriod.rawValue, systemImage: "calendar")
                }
            }
        }
    }
}

// MARK: - VelocityRow

/// A view-model row pairing a repository display name with its velocity comparison.
private struct VelocityRow: Identifiable {

    /// A stable identifier for use in `ForEach`.
    let id = UUID()

    /// The repository display name.
    let name: String

    /// The current-vs-prior velocity comparison for the selected period.
    let comparison: VelocityComparison
}

// MARK: - VelocityRepoRow

/// A single list row showing a repository's merged PR count and week-over-week trend.
private struct VelocityRepoRow: View {

    // MARK: - Properties

    /// The velocity row data to render.
    let row: VelocityRow

    // MARK: - Body

    /// The view's content.
    var body: some View {
        LabeledContent {
            HStack(spacing: 4) {
                Text("\(row.comparison.current)")
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                trendView
            }
        } label: {
            Text(row.name)
        }
    }

    // MARK: - Helpers

    /// The trend indicator icon and color for the comparison's direction.
    private var trendView: some View {
        Group {
            switch row.comparison.trend {
            case .up:
                Image(systemName: "arrow.up")
                    .foregroundStyle(.green)
                    .imageScale(.small)
            case .down:
                Image(systemName: "arrow.down")
                    .foregroundStyle(.red)
                    .imageScale(.small)
            case .flat:
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
        }
    }
}

// MARK: - VelocityPeriod + Display

private extension VelocityPeriod {

    /// A human-readable label used in the hero row subtitle.
    var displayLabel: String {
        switch self {
        case .sevenDays: return "Merged PRs · 7 days"
        case .thirtyDays: return "Merged PRs · 30 days"
        case .ninetyDays: return "Merged PRs · 90 days"
        case .yearToDate: return "Merged PRs · Year to date"
        }
    }
}
