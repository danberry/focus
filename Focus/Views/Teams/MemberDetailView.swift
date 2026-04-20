import SwiftUI
import SwiftData

// MARK: - MemberDetailView

/// Displays contribution history and summary statistics for a single team member.
struct MemberDetailView: View {

    // MARK: - Properties

    /// The team member whose contribution data this view displays.
    let member: Member

    /// The currently selected time range, controlling which contributions are shown.
    @State private var selectedRange: TimeRange = .oneYear

    /// The contributions for the selected time range, sorted chronologically.
    private var filteredDays: [DailyContribution] {
        let cutoff = selectedRange.cutoffDate
        return member.dailyContributions
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        // Compute expensive values once per render instead of once per cell
        let days = filteredDays
        let maxCount = days.map(\.count).max() ?? 1
        let rows = buildGridRows(from: days)

        // Single-pass summary stats instead of three separate scans
        let stats = summaryStats(from: days)

        List {
            // MARK: Details
            if member.jobTitle != nil || member.manager != nil {
                Section("Details") {
                    if let title = member.jobTitle {
                        LabeledContent("Job Title", value: title.name)
                    }
                    if let manager = member.manager {
                        LabeledContent("Manager", value: manager.name)
                    }
                }
            }

            // MARK: Contributions
            Section {
                if days.isEmpty {
                    Text("No contribution data available.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                } else {
                    LabeledContent {} label: {
                        Text(stats.total, format: .number)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .contentTransition(.numericText())
                        Text("total")
                            .textCase(.uppercase)
                    }
                    .glassCardEffect()
                }
            } header: {
                HStack() {
                    Text("Contributions")
                    Menu {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Button {
                                withAnimation {
                                    selectedRange = range
                                }
                            } label: {
                                Label(
                                    range.rawValue,
                                    systemImage: selectedRange == range ? "checkmark" : ""
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                Color.accentColor.tertiary,
                                in: .capsule
                            )
                    }
                }
            }
            .listRowSeparator(.hidden)
            .listSectionSpacing(18)

            // MARK: Contribution Grid
            Section {
                contributionGridView(rows: rows, maxCount: maxCount)
            }
        }
        .listStyle(.plain)
        .headerProminence(.increased)
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    /// Builds a grid of contribution cells from the given days, arranged in rows of ten.
    private func contributionGridView(rows: [[GridCell]], maxCount: Int) -> some View {
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(0..<10, id: \.self) { col in
                        let row = rows[rowIndex]
                        let color: Color = col < row.count
                            ? contributionColor(for: row[col].count, date: row[col].date, maxCount: maxCount)
                            : .clear
                        let border: Color = col < row.count && row[col].count == 0
                        ? color.mix(with: .primary, by: 0.15)
                        : .clear
                        Circle()
                            .stroke(border, lineWidth: 2)
                            .fill(color)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    /// Computes total contributions, active day count, and peak day count in a single pass.
    private func summaryStats(from days: [DailyContribution]) -> (total: Int, activeDays: Int, peak: Int) {
        var total = 0
        var activeDays = 0
        var peak = 0
        for day in days {
            total += day.count
            if day.count > 0 { activeDays += 1 }
            if day.count > peak { peak = day.count }
        }
        return (total, activeDays, peak)
    }

    /// Builds rows of grid cells covering every day from the cutoff date through today.
    private func buildGridRows(from days: [DailyContribution]) -> [[GridCell]] {
        guard !days.isEmpty else { return [] }

        let calendar = Calendar.current

        // Build a date → contribution lookup
        var lookup: [Date: DailyContribution] = [:]
        for day in days {
            lookup[calendar.startOfDay(for: day.date)] = day
        }

        // Expand the full date range day-by-day, preserving the date for every cell
        let start = calendar.startOfDay(for: selectedRange.cutoffDate)
        let endDay = calendar.startOfDay(for: Date())
        var current = start
        var allDays: [GridCell] = []
        while current <= endDay {
            allDays.append(GridCell(date: current, count: lookup[current]?.count ?? 0))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        // Chunk into rows of 15
        return stride(from: 0, to: allDays.count, by: 10).map {
            Array(allDays[$0..<min($0 + 10, allDays.count)])
        }
    }

    /// Returns the fill color for a contribution cell based on count, date, and the period's maximum.
    private func contributionColor(for count: Int, date: Date, maxCount: Int) -> Color {
        let weekday = Calendar.current.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let baseColor: Color

        if isWeekend && count > 0 {
            baseColor = .accentedRed
        }
        else {
            baseColor = .accentedGreen
        }

        let mixAmount: CGFloat
        let ratio = Double(count) / Double(maxCount)
        switch ratio {
        case 0:
            mixAmount = 0.8
        case ..<0.25:
            mixAmount = 0.65
        case ..<0.50:
            mixAmount = 0.55
        case ..<0.75:
            mixAmount = 0.4
        case ..<0.95:
            mixAmount = 0.2
        default:
            mixAmount = 0
        }

        return baseColor.mix(with: Color(.systemBackground), by: mixAmount)
    }

    /// Returns a labeled row displaying a summary statistic.
    private func summaryRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - GridCell

/// A single cell in the contribution grid, pairing a calendar date with its contribution count.
private struct GridCell {
    /// The calendar date this cell represents.
    let date: Date
    /// The number of contributions on this date.
    let count: Int
}

// MARK: - TimeRange

/// The selectable time windows for filtering contribution history.
private enum TimeRange: String, CaseIterable, Identifiable {
    /// The trailing 30-day window.
    case thirtyDays = "30D"
    /// The trailing 90-day window.
    case ninetyDays = "90D"
    /// The trailing one-year window.
    case oneYear = "1Y"

    /// The stable identifier for this range.
    var id: String { rawValue }

    /// The human-readable label for this range.
    var label: String { rawValue }

    /// The earliest date included in this time range.
    var cutoffDate: Date {
        let days: Int
        switch self {
        case .thirtyDays: days = -29
        case .ninetyDays: days = -89
        case .oneYear: days = -364
        }
        return Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}
