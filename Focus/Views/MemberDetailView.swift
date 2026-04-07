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

    private var maxCount: Int {
        filteredDays.map(\.count).max() ?? 1
    }

    private var gridRows: [[DailyContribution?]] {
        guard !filteredDays.isEmpty else { return [] }

        // Build a date → contribution lookup
        var lookup: [Date: DailyContribution] = [:]
        for day in filteredDays {
            lookup[Calendar.current.startOfDay(for: day.date)] = day
        }

        // Expand the full date range day-by-day
        let start = Calendar.current.startOfDay(for: selectedRange.cutoffDate)
        let endDay = Calendar.current.startOfDay(for: Date())
        var current = start
        var days: [DailyContribution?] = []
        while current <= endDay {
            days.append(lookup[current])
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        }

        // Pad the front so the first cell lands on its correct weekday column (1=Sun…7=Sat)
        let firstWeekday = Calendar.current.component(.weekday, from: start)
        let leadingNils: [DailyContribution?] = Array(repeating: nil, count: firstWeekday - 1)
        let padded = leadingNils + days

        // Chunk into rows of 7
        return stride(from: 0, to: padded.count, by: 7).map {
            Array(padded[$0..<min($0 + 7, padded.count)])
        }
    }

    var body: some View {
        List {
            Section {
                rangePickerView
                if filteredDays.isEmpty {
                    Text("No contribution data available.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                } else {
                    contributionGridView
                }
            }

            Section("Summary") {
                summaryRow(label: "Total contributions", value: filteredDays.reduce(0) { $0 + $1.count })
                summaryRow(label: "Active days", value: filteredDays.filter { $0.count > 0 }.count)
                if let peak = filteredDays.max(by: { $0.count < $1.count }), peak.count > 0 {
                    summaryRow(label: "Peak day", value: peak.count)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(member.name)
    }

    // MARK: - Subviews

    private var rangePickerView: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)
        .padding(.vertical, 4)
    }

    private var contributionGridView: some View {
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(dayLabels.indices, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(gridRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let cell: DailyContribution? = col < gridRows[rowIndex].count
                            ? gridRows[rowIndex][col]
                            : nil
                        Circle()
                            .fill(contributionColor(for: cell?.count ?? 0))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .padding(.vertical, 8)
    }

    private func contributionColor(for count: Int) -> Color {
        if count == 0 { return Color(.systemFill) }
        let ratio = Double(count) / Double(maxCount)
        switch ratio {
        case ..<0.25: return Color.accentColor.opacity(0.25)
        case ..<0.50: return Color.accentColor.opacity(0.45)
        case ..<0.75: return Color.accentColor.opacity(0.65)
        default:      return Color.accentColor.opacity(0.90)
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
        case .thirtyDays: days = -30
        case .ninetyDays: days = -90
        case .oneYear: days = -365
        }
        return Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}
