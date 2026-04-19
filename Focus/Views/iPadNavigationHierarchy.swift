import SwiftUI

// MARK: - iPadNavigationHierarchy

/// Displays the current navigation hierarchy in the iPad navigation bar's leading slot.
///
/// Tapping the label opens a menu listing all top-level destinations, allowing the user
/// to switch content without drilling into a deeper navigation level.
struct iPadNavigationHierarchy: View {

    // MARK: - Properties

    /// The navigation coordinator providing the current destination and handling navigation.
    let coordinator: iPadNavigationCoordinator

    // MARK: - Body

    /// The view's content.
    var body: some View {
        if let title = coordinator.currentTitle {
            Menu {
                ForEach(iPadNavigationDestination.allCases, id: \.title) { destination in
                    Button {
                        withAnimation(.easeOut(duration: 0.35)) {
                            coordinator.navigate(to: destination)
                        }
                    } label: {
                        Label(destination.title, systemImage: destination == coordinator.stack.last ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundStyle(BriefingColor.ink3)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(BriefingColor.ink3)
                }
            }
        }
    }
}
