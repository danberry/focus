import SwiftUI
import Charts

// MARK: - JobTitleDonutChartView

/// Displays a donut chart breaking down team members by job title.
struct JobTitleDonutChartView: View {

    // MARK: - Properties

    /// The members whose job titles are visualized.
    let members: [Member]

    /// The chart data derived from member job titles, sorted by count descending then title ascending.
    private var slices: [TitleSlice] {
        var counts: [String: Int] = [:]
        for member in members {
            let key = member.jobTitle?.name ?? "Unassigned"
            counts[key, default: 0] += 1
        }
        return counts
            .map { TitleSlice(title: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.title < $1.title }
    }

    /// The fixed color palette applied to chart slices, cycling if there are more titles than colors.
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
        let data = slices
        let total = members.count

        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Chart(data) { slice in
                    SectorMark(
                        angle: .value("Members", slice.count),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Job Title", slice.title))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale(
                    domain: data.map(\.title),
                    range: data.indices.map { Self.palette[$0 % Self.palette.count] }
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
                ForEach(data.indices, id: \.self) { index in
                    let slice = data[index]
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Self.palette[index % Self.palette.count])
                            .frame(width: 12, height: 12)
                        Text(slice.title)
                            .font(.caption)
                        Spacer()
                        Text("\(slice.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - TitleSlice

/// A single slice in the job title donut chart, representing one title and its member count.
private struct TitleSlice: Identifiable {

    /// The job title label, or `"Unassigned"` if the member has no job title.
    let title: String

    /// The number of members with this job title.
    let count: Int

    /// A stable identifier for this slice, equal to the title string.
    var id: String { title }
}
