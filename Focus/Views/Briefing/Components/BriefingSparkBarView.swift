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

    /// The semantic tone that drives the active bar color.
    let tone: BriefingTone

    /// When `true`, the bar at the highest value is rendered in green.
    var highlightPeak: Bool = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        let clipped = Array(values.prefix(10))
        let peakIndex = highlightPeak ? clipped.indices.max(by: { clipped[$0] < clipped[$1] }) : nil
        HStack(spacing: 2) {
            ForEach(Array(clipped.enumerated()), id: \.offset) { index, value in
                Rectangle()
                    .fill(barColor(for: value, isPeak: index == peakIndex))
                    .frame(width: 3, height: max(0.2, value) * 20)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
            }
        }
        .frame(height: 20)
    }

    // MARK: - Helpers

    /// Returns the fill color for a single bar, accounting for peak highlight and zero-value fallback.
    private func barColor(for value: Double, isPeak: Bool) -> Color {
        guard value > 0 else { return BriefingColor.ink4 }
        if isPeak { return BriefingColor.green }
        switch tone {
        case .red: return BriefingColor.red
        case .blue, .neutral: return BriefingColor.ink
        }
    }
}

// MARK: - Preview

#Preview {
    BriefingSparkBarView(
        values: [0.3, 0.5, 0.6, 0.4, 0.7, 0.8, 0.6, 0.9, 0.7, 1.0],
        tone: .neutral
    )
    .padding()
}
