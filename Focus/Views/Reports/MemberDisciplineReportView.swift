import SwiftUI
import SwiftData
import Charts

// MARK: - MemberDisciplineReportView

/// Displays team members grouped by discipline with a donut chart summary.
struct MemberDisciplineReportView: View {

    // MARK: - Properties

    /// All members, sorted alphabetically by name.
    @Query(sort: \Member.name) private var members: [Member]

    /// Members grouped and sorted by discipline name, with "Unassigned" last.
    private var sections: [(discipline: String, members: [Member])] {
        var grouped: [String: [Member]] = [:]
        for member in members {
            let key = member.jobTitle?.discipline?.name ?? "Unassigned"
            grouped[key, default: []].append(member)
        }
        return grouped
            .map { (discipline: $0.key, members: $0.value.sorted { $0.name < $1.name }) }
            .sorted {
                if $0.discipline == "Unassigned" { return false }
                if $1.discipline == "Unassigned" { return true }
                return $0.discipline < $1.discipline
            }
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Group {
            if members.isEmpty {
                ContentUnavailableView(
                    "No Members",
                    systemImage: "person.3",
                    description: Text("Add members to see a breakdown by discipline.")
                )
            } else {
                List {
                    Section {
                        DisciplineBreakdownChartView(sections: sections)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                    ForEach(sections, id: \.discipline) { section in
                        Section {
                            ForEach(section.members) { member in
                                Text(member.name)
                            }
                        } header: {
                            HStack {
                                Text(section.discipline)
                                Spacer()
                                Text("\(section.members.count)")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Members by Discipline")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - DisciplineBreakdownChartView

/// A donut chart and legend showing member counts by discipline.
private struct DisciplineBreakdownChartView: View {

    // MARK: - Properties

    /// The discipline sections to render, each with a name and member list.
    let sections: [(discipline: String, members: [Member])]

    /// The color palette used to differentiate disciplines in the chart and legend.
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

    /// The total number of members across all sections.
    private var total: Int { sections.reduce(0) { $0 + $1.members.count } }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: Chart
            ZStack {
                Chart(sections.indices, id: \.self) { index in
                    let section = sections[index]
                    SectorMark(
                        angle: .value("Members", section.members.count),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Discipline", section.discipline))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale(
                    domain: sections.map(\.discipline),
                    range: sections.indices.map { Self.palette[$0 % Self.palette.count] }
                )
                .chartLegend(.hidden)
                .frame(height: 180)

                VStack(spacing: 2) {
                    Text("\(total)")
                        .font(.title2.bold())
                    Text(total == 1 ? "member" : "members")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Legend
            VStack(alignment: .leading, spacing: 6) {
                ForEach(sections.indices, id: \.self) { index in
                    let section = sections[index]
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Self.palette[index % Self.palette.count])
                            .frame(width: 12, height: 12)
                        Text(section.discipline)
                            .font(.caption)
                        Spacer()
                        Text("\(section.members.count)")
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
