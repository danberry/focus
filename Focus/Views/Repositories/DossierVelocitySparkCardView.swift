import SwiftUI

// MARK: - DossierVelocitySparkCardView

/// A dossier card displaying a 26-week commit velocity trend as a smooth area chart.
///
/// The header row shows the period label and a percentage-change badge comparing
/// the second half of the window to the first. Month abbreviations are drawn along
/// the bottom axis of the chart so both the heatmap and velocity card present a
/// unified 26-week picture.
struct DossierVelocitySparkCardView: View {

    // MARK: - Properties

    /// Weekly commit counts for the area chart, ordered oldest to newest (26 values).
    let weeklyCommits: [Int]

    /// Percentage change comparing the last 13 weeks to the first 13 weeks, or `nil` when
    /// insufficient data is available.
    let percentageChange: Double?

    /// The Sunday that anchors the left edge of the 26-week window, used to place month labels.
    let startDate: Date?

    // MARK: - Body

    /// The view's content.
    var body: some View {
        DossierCardView {
            VStack(alignment: .leading, spacing: 8) {
                header
                if weeklyCommits.isEmpty {
                    emptyText
                } else {
                    VelocityAreaChartView(values: weeklyCommits, startDate: startDate)
                }
            }
        }
    }

    // MARK: - Private

    /// Header row: period label on the left, percentage-change badge on the right.
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("VELOCITY · 26W")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(BriefingColor.ink3)
            Spacer()
            if let pct = percentageChange {
                let symbol = pct >= 0 ? "↑" : "↓"
                let absPercent = Int((abs(pct) * 100).rounded())
                Text("\(symbol) \(absPercent)%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(pct >= 0 ? BriefingColor.green : BriefingColor.red)
            }
        }
    }

    private var emptyText: some View {
        Text("No data")
            .font(BriefingFont.body)
            .foregroundStyle(BriefingColor.ink3)
    }
}

// MARK: - VelocityAreaChartView

/// A smooth area chart rendered via `Canvas`, with month labels along the bottom axis.
private struct VelocityAreaChartView: View {

    // MARK: - Properties

    let values: [Int]
    let startDate: Date?

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let n = values.count
            let normalized = normalizedValues()
            // Reserve 20pt at the bottom for month labels when a start date is available.
            let chartBottom = size.height - (startDate != nil ? 20 : 0)

            func point(at i: Int) -> CGPoint {
                CGPoint(
                    x: size.width * CGFloat(i) / CGFloat(n - 1),
                    y: chartBottom * CGFloat(1.0 - normalized[i])
                )
            }

            // Build a smooth line using cubic bezier with midpoint control points.
            var line = Path()
            line.move(to: point(at: 0))
            for i in 1..<n {
                let p0 = point(at: i - 1)
                let p1 = point(at: i)
                let midX = (p0.x + p1.x) / 2
                line.addCurve(to: p1,
                              control1: CGPoint(x: midX, y: p0.y),
                              control2: CGPoint(x: midX, y: p1.y))
            }

            // Area fill below the line.
            var area = line
            area.addLine(to: CGPoint(x: size.width, y: chartBottom))
            area.addLine(to: CGPoint(x: 0, y: chartBottom))
            area.closeSubpath()
            context.fill(area, with: .color(BriefingColor.ink.opacity(0.08)))

            // Line stroke on top of the fill.
            context.stroke(line, with: .color(BriefingColor.ink), lineWidth: 1.5)

            // Month labels along the bottom axis.
            if let start = startDate {
                for (label, fraction) in monthLabels(startDate: start, count: n) {
                    context.draw(
                        Text(label)
                            .font(BriefingFont.meta)
                            .foregroundStyle(BriefingColor.ink3),
                        at: CGPoint(x: size.width * CGFloat(fraction), y: size.height - 8),
                        anchor: .center
                    )
                }
            }
        }
        .frame(height: startDate != nil ? 100 : 80)
    }

    // MARK: - Helpers

    /// Returns normalized (0–1) values after applying a 5-point centered moving average
    /// to smooth out week-to-week jitter and surface the overall trend.
    private func normalizedValues() -> [Double] {
        let smoothed = movingAverage(values.map(Double.init), window: 5)
        guard let peak = smoothed.max(), peak > 0 else { return smoothed.map { _ in 0 } }
        return smoothed.map { $0 / peak }
    }

    /// Applies a centered moving average with the given odd `window` size.
    /// Edge values use a narrower window rather than zero-padding to avoid artificial dips.
    private func movingAverage(_ values: [Double], window: Int) -> [Double] {
        let half = window / 2
        return values.indices.map { i in
            let lo = max(0, i - half)
            let hi = min(values.count - 1, i + half)
            let slice = values[lo...hi]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    /// Returns `(abbreviation, fraction)` pairs for each month boundary that falls within
    /// the `count`-week window starting at `startDate`.
    private func monthLabels(startDate: Date, count: Int) -> [(String, Double)] {
        guard count > 1 else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        fmt.timeZone = TimeZone(identifier: "UTC")!

        let totalDays = count * 7
        var result: [(String, Double)] = []
        var seenMonths = Set<Int>()

        for dayOffset in 0..<totalDays {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let day = cal.component(.day, from: date)
            let month = cal.component(.month, from: date)
            if day == 1 && !seenMonths.contains(month) {
                seenMonths.insert(month)
                let fraction = Double(dayOffset) / Double(totalDays - 1)
                result.append((fmt.string(from: date), fraction))
            }
        }
        return result
    }
}

// MARK: - Preview

#Preview {
    DossierVelocitySparkCardView(
        weeklyCommits: [85, 92, 78, 110, 45, 85, 125, 105, 95, 140, 120, 80, 110, 135, 150, 120, 95, 105, 88, 115, 132, 145, 128, 140, 155, 120],
        percentageChange: 0.22,
        startDate: Calendar.current.date(byAdding: .weekOfYear, value: -26, to: Date())
    )
    .padding()
    .background(BriefingColor.paper)
}
