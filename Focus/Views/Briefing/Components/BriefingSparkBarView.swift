import SwiftUI

// MARK: - BriefingSparkBarView

/// A compact bar-chart sparkline used inside Focus Briefing KPI cards.
///
/// Renders up to ten 3pt-wide bars with heights proportional to their normalized values.
/// The shipping KPI passes seven bars (one per day). Zero-value bars receive a low-emphasis
/// ink color so the silhouette remains visible.
struct BriefingSparkBarView: View {

    // MARK: - Properties

    /// Normalized values in the range `0.0`–`1.0`. Up to ten elements are rendered.
    let values: [Double]

    // MARK: - Body

    /// The view's content.
    var body: some View {
        let clipped = Array(values.prefix(10))
        let lastIndex = clipped.indices.last
        HStack(spacing: 2) {
            ForEach(Array(clipped.enumerated()), id: \.offset) { index, value in
                Rectangle()
                    .fill(barColor(for: value, isLast: index == lastIndex))
                    .frame(width: 3, height: max(0.2, value) * 20)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
            }
        }
        .frame(height: 20)
    }

    // MARK: - Helpers

    /// Returns the fill color for a single bar: dark ink for the most recent bar, light gray for all others.
    private func barColor(for value: Double, isLast: Bool) -> Color {
        guard value > 0 else { return BriefingColor.ink4 }
        return isLast ? BriefingColor.green : BriefingColor.ink4
    }
}

// MARK: - Preview

#Preview {
    BriefingSparkBarView(
        values: [0.3, 0.5, 0.6, 0.4, 0.7, 0.8, 0.6, 0.9, 0.7, 1.0]
    )
    .padding()
}
