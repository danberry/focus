import SwiftUI
import SwiftData

// MARK: - MemberDetailView

struct MemberDetailView: View {
    let member: Member

    @State private var selectedRange: TimeRange = .oneYear

    private var filteredDays: [DailyContribution] {
        let cutoff = selectedRange.cutoffDate
        return member.dailyContributions
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        // Compute expensive values once per render instead of once per cell
        let days = filteredDays
        let maxCount = days.map(\.count).max() ?? 1
        let rows = buildGridRows(from: days)

        // Single-pass summary stats instead of three separate scans
        let stats = summaryStats(from: days)

        List {
            Section {
                if days.isEmpty {
                    Text("No contribution data available.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                } else {
                    contributionGridView(rows: rows, maxCount: maxCount)
                }
            }

            Section("Summary") {
                if let jobTitle = member.jobTitle {
                    HStack {
                        Text("Job title")
                        Spacer()
                        Text(jobTitle.name)
                            .foregroundStyle(.secondary)
                    }
                }
                summaryRow(label: "Total contributions", value: stats.total)
                summaryRow(label: "Active days", value: stats.activeDays)
                if stats.peak > 0 {
                    summaryRow(label: "Peak day", value: stats.peak)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(member.name)
    }

    // MARK: - Subviews

    private func contributionGridView(rows: [[GridCell]], maxCount: Int) -> some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let fromLabel = formatter.string(from: selectedRange.cutoffDate)
        let toLabel = formatter.string(from: Date())

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(fromLabel) – \(toLabel)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button(range.label) { selectedRange = range }
                    }
                } label: {
                    Image(systemName: "calendar")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)

            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(0..<15, id: \.self) { col in
                        let row = rows[rowIndex]
                        let color: Color = col < row.count
                            ? contributionColor(for: row[col].count, date: row[col].date, maxCount: maxCount)
                            : .clear
                        Circle()
                            .fill(color)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

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
        return stride(from: 0, to: allDays.count, by: 15).map {
            Array(allDays[$0..<min($0 + 15, allDays.count)])
        }
    }

    private func contributionColor(for count: Int, date: Date, maxCount: Int) -> Color {
        let weekday = Calendar.current.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7  // 1 = Sunday, 7 = Saturday
        if count == 0 {
            return isWeekend ? Color(.systemGray3) : Color(.systemFill)
        }
        let ratio = Double(count) / Double(maxCount)
        let baseColor: Color = isWeekend ? .accentedRed : .accentColor
        switch ratio {
        case ..<0.25: return baseColor.opacity(0.25)
        case ..<0.50: return baseColor.opacity(0.45)
        case ..<0.75: return baseColor.opacity(0.65)
        default:      return baseColor.opacity(0.90)
        }
    }

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

private struct GridCell {
    let date: Date
    let count: Int
}

// MARK: - TimeRange

private enum TimeRange: String, CaseIterable, Identifiable {
    case thirtyDays = "30D"
    case ninetyDays = "90D"
    case oneYear = "1Y"

    var id: String { rawValue }

    var label: String { rawValue }

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
