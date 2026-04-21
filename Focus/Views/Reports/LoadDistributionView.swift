import SwiftUI
import SwiftData
import Charts

// MARK: - LoadDistributionView

/// Displays contribution workload distribution across team members for the most recent sync period.
struct LoadDistributionView: View {

    // MARK: - Properties

    /// All members, sorted alphabetically by name.
    @Query(sort: \Member.name) private var members: [Member]

    /// The currently selected contribution metric used to compute and sort member load.
    @State private var selectedMetric: Metric = .total

    /// Member load rows sorted by selected metric descending, filtering out members with no contribution records.
    private var rows: [MemberLoad] {
        members
            .compactMap { member -> MemberLoad? in
                guard !member.contributions.isEmpty else { return nil }
                let value = value(for: selectedMetric, contribution: member.contributions.first)
                return MemberLoad(member: member, value: value)
            }
            .sorted { $0.value > $1.value }
    }

    /// The total contribution count across all visible rows for computing percentages.
    private var totalValue: Int { rows.reduce(0) { $0 + $1.value } }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Group {
            if members.isEmpty {
                ContentUnavailableView(
                    "No Members",
                    systemImage: "person.3",
                    description: Text("Add members to a team to see load distribution.")
                )
            } else if rows.isEmpty {
                ContentUnavailableView(
                    "No Contribution Data",
                    systemImage: "chart.bar",
                    description: Text("Sync member contributions to see load distribution.")
                )
            } else {
                List {
                    // MARK: Chart
                    Section {
                        LoadBarChartView(rows: rows, metric: selectedMetric)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }

                    // MARK: Members
                    Section {
                        ForEach(rows) { row in
                            LabeledContent {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(row.value, format: .number)
                                        .monospacedDigit()
                                        .fontWeight(.medium)
                                    if totalValue > 0 {
                                        Text(shareLabel(row.value))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } label: {
                                Text(row.member.name)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Load Distribution")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MetricPickerView(selectedMetric: $selectedMetric)
        }
    }

    // MARK: - Private

    /// Returns the contribution count for the given metric from a single contribution record.
    private func value(for metric: Metric, contribution: MemberContribution?) -> Int {
        guard let contribution else { return 0 }
        switch metric {
        case .total:    return contribution.commits + contribution.pullRequests + contribution.reviews + contribution.issues
        case .commits:  return contribution.commits
        case .prs:      return contribution.pullRequests
        case .reviews:  return contribution.reviews
        case .issues:   return contribution.issues
        }
    }

    /// Returns a formatted percentage string for `value` relative to the total.
    private func shareLabel(_ value: Int) -> String {
        guard totalValue > 0 else { return "" }
        let percent = Double(value) / Double(totalValue) * 100
        return String(format: "%.0f%%", percent)
    }
}

// MARK: - Metric

/// The contribution activity type used to measure and rank member workload.
enum Metric: String, CaseIterable {

    /// The sum of commits, pull requests, reviews, and issues.
    case total = "Total"

    /// The number of commits authored.
    case commits = "Commits"

    /// The number of pull requests opened.
    case prs = "PRs"

    /// The number of pull request reviews submitted.
    case reviews = "Reviews"

    /// The number of issues opened.
    case issues = "Issues"
}

// MARK: - MemberLoad

/// A single row in the load distribution report, pairing a member with their computed metric value.
private struct MemberLoad: Identifiable {

    /// The team member this load record represents.
    let member: Member

    /// The contribution count for the selected metric.
    let value: Int

    /// A stable identifier derived from the underlying member.
    var id: PersistentIdentifier { member.id }
}

// MARK: - LoadBarChartView

/// A horizontal bar chart showing relative contribution load for each member.
private struct LoadBarChartView: View {

    // MARK: - Properties

    /// The member load rows to render, in display order.
    let rows: [MemberLoad]

    /// The active metric label shown in the chart axis title.
    let metric: Metric

    /// The color palette applied to bars, cycling if there are more members than colors.
    private static let palette: [Color] = [
        .accentedBlue,
        .accentedGreen,
        .accentedOrange,
        .accentedPurple,
        .accentedRed,
        .accentedTeal,
        .accentedIndigo,
        .accentedYellow,
    ]

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Chart(rows.indices, id: \.self) { index in
            let row = rows[index]
            BarMark(
                x: .value(metric.rawValue, row.value),
                y: .value("Member", row.member.name)
            )
            .foregroundStyle(Self.palette[index % Self.palette.count])
            .cornerRadius(4)
            .annotation(position: .trailing, alignment: .leading) {
                Text(row.value, format: .number)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .frame(height: max(160, CGFloat(rows.count) * 36))
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

// MARK: - MetricPickerView

/// A floating segmented picker anchored to the bottom of the screen for selecting the active metric.
private struct MetricPickerView: View {

    // MARK: - Properties

    /// The currently selected metric, updated when the user picks a new segment.
    @Binding var selectedMetric: Metric

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Picker("Metric", selection: $selectedMetric) {
                ForEach(Metric.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }
}
