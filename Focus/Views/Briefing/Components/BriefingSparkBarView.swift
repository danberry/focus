import SwiftUI

// MARK: - BriefingSparkBarView

/// A full-width bar-chart sparkline used inside Focus Briefing KPI cards.
///
/// Bars stretch to fill the available width with equal spacing. Heights are
/// proportional to the normalized input values. The peak bar renders in red;
/// all others render in a low-emphasis gray.
struct BriefingSparkBarView: View {

    // MARK: - Properties

    /// Normalized values in the range `0.0`–`1.0`. Up to fourteen elements are rendered.
    let values: [Double]

    private let maxHeight: CGFloat = 48
    private let spacing: CGFloat = 3

    // MARK: - Body

    var body: some View {
        let clipped = Array(values.prefix(14))
        let peakIndex = clipped.indices.max(by: { clipped[$0] < clipped[$1] })
        GeometryReader { geo in
            let count = CGFloat(clipped.count)
            let barWidth = max(1, (geo.size.width - spacing * (count - 1)) / count)
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(clipped.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index == peakIndex && value > 0 ? BriefingColor.red : BriefingColor.ink4)
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
