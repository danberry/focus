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
    var highlightColor: Color = .customGreen

    /// Maximum bar height in points. Defaults to `20` for compact KPI card use.
    var maxHeight: CGFloat = 20

    // MARK: - Body

    var body: some View {
        let clipped = Array(values.prefix(14))
        let peakValue = clipped.max() ?? 0
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(clipped.enumerated()), id: \.offset) {
                index,
                value in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        peakValue > 0 && value == peakValue ? highlightColor : .gray600
                    )
                    .frame(height: max(1, value * maxHeight))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .bottomLeading)
    }
}

// MARK: - Preview

#Preview {
    BriefingSparkBarView(
        values: [0.3, 0.5, 0.6, 0.4, 0.7, 0.8, 0.6, 0.9, 0.7, 1.0]
    )
    .padding()
}
