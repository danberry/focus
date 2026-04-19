import SwiftUI

// MARK: - MainSplitView

/// The root interface for iPadOS, providing the foundation for a custom navigation system.
struct MainSplitView: View {

    // MARK: - Properties

    /// The navigation coordinator driving the content area and hierarchy display.
    @State private var coordinator = iPadNavigationCoordinator()

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(spacing: 0) {
            iPadNavigationBar {
                HStack(spacing: 16) {
                    Text("Focus")
                        .fontWeight(.bold)
                        .foregroundStyle(BriefingColor.ink)

                    Divider()
                        .frame(height: 14)
                        .background(BriefingColor.rule)

                    iPadNavigationHierarchy(coordinator: coordinator)
                }
            } center: {
                Rectangle()
                    .fill(.clear)
            } trailing: {
                Rectangle()
                    .fill(.clear)
            }
            iPadContentView(coordinator: coordinator)
        }
    }
}
