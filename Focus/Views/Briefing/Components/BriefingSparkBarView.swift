import SwiftUI

// MARK: - BriefingSparkBarView

/// A full-width bar-chart sparkline used inside Focus Briefing KPI cards.
///
/// Bars stretch to fill the available width with equal spacing. Heights are
/// proportional to the normalized input values. The peak bar renders in
/// `highlightColor`; all others render in a low-emphasis gray.
struct BriefingSparkBarView: View {

    // MARK: - Properties

    /// Normalized values in the range `0.0`–`1.0`. Up to fourteen elements are rendered.
    let values: [Double]

    /// Color used to highlight the bar with the largest value. Defaults to green.
    var highlightColor: Color = BriefingColor.green

    private let maxHeight: CGFloat = 48
    private let spacing: CGFloat = 3

    // MARK: - Body

    var body: some View {
        let clipped = Array(values.prefix(14))
        let peakValue = clipped.max() ?? 0
        GeometryReader { geo in
            let count = CGFloat(clipped.count)
            let barWidth = max(1, (geo.size.width - spacing * (count - 1)) / count)
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(clipped.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(peakValue > 0 && value == peakValue ? highlightColor : BriefingColor.ink4)
                        .frame(width: barWidth, height: max(2, value * maxHeight))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: maxHeight)
    }
}

// MARK: - Preview

#Preview {
    BriefingSparkBarView(
        values: [0.3, 0.5, 0.6, 0.4, 0.7, 0.8, 0.6, 0.9, 0.7, 1.0]
    )
    .padding()
}
