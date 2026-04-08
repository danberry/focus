import SwiftUI
import Charts

// MARK: - JobTitleDonutChartView

struct JobTitleDonutChartView: View {
    let members: [Member]

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

            // Legend
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

private struct TitleSlice: Identifiable {
    let title: String
    let count: Int
    var id: String { title }
}
