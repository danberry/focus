import SwiftUI
import Charts
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
        List {
            Section {
                rangePickerView
                chartView
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

    @ViewBuilder
    private var chartView: some View {
        if filteredDays.isEmpty {
            Text("No contribution data available.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
        } else {
            Chart(filteredDays) { day in
                LineMark(
                    x: .value("Date", day.date),
                    y: .value("Contributions", day.count)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: selectedRange.xAxisStride)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: selectedRange.xAxisLabelFormat)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
            .listRowSeparator(.hidden)
            .padding(.vertical, 8)
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

    var xAxisStride: Calendar.Component {
        switch self {
        case .thirtyDays: return .weekOfYear
        case .ninetyDays: return .month
        case .oneYear: return .month
        }
    }

    var xAxisLabelFormat: Date.FormatStyle {
        switch self {
        case .thirtyDays: return .dateTime.month().day()
        case .ninetyDays: return .dateTime.month()
        case .oneYear: return .dateTime.month()
        }
    }
}
