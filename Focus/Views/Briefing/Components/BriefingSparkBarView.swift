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

    // MARK: - Body

    /// The view's content.
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(values.prefix(10).enumerated()), id: \.offset) { _, value in
                Rectangle()
                    .fill(barColor(for: value))
                    .frame(width: 3, height: max(0.2, value) * 20)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
            }
        }
        .frame(height: 20)
    }

    // MARK: - Helpers

    /// Returns the fill color for a single bar, accounting for zero-value fallback.
    private func barColor(for value: Double) -> Color {
        guard value > 0 else { return BriefingColor.ink4 }
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
