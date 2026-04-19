import SwiftUI

// MARK: - iPadNavigationBar

/// The custom navigation bar displayed at the top of the iPad root interface.
///
/// Accepts independent leading, center, and trailing content slots. The center
/// slot is rendered via `ZStack` overlay so it remains geometrically centered
/// regardless of leading/trailing content widths.
struct iPadNavigationBar<Leading: View, Center: View, Trailing: View>: View {

    // MARK: - Properties

    /// The view placed at the leading edge of the bar.
    let leading: Leading

    /// The view placed at the horizontal center of the bar.
    let center: Center

    /// The view placed at the trailing edge of the bar.
    let trailing: Trailing

    // MARK: - Init

    /// Creates a navigation bar with leading, center, and trailing content slots.
    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(spacing: .zero) {
            Grid {
                GridRow {
                    leading
                        .frame(maxWidth: .infinity, alignment: .leading)
                    center
                        .frame(maxWidth: .infinity)
                    trailing
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity)
            Divider()
                .background(BriefingColor.rule)
        }
        .frame(height: 70)
        .background(BriefingColor.paper)
    }
}
