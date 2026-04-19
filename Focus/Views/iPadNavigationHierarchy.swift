import SwiftUI

// MARK: - iPadNavigationHierarchy

/// Displays the navigation stack as a breadcrumb trail in the iPad navigation bar's leading slot.
///
/// Each ancestor destination is rendered as a tappable label that pops the stack back to that
/// level. The current (deepest) destination shows a ``Menu`` when it is a root destination,
/// allowing the user to switch sections without popping first.
struct iPadNavigationHierarchy: View {

    // MARK: - Properties

    /// The navigation coordinator providing the stack and handling navigation.
    let coordinator: iPadNavigationCoordinator

    // MARK: - Body

    /// The view's content.
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(coordinator.stack.enumerated()), id: \.offset) { index, destination in
                if index > 0 {
                    Text("/")
                        .font(.system(size: 11))
                        .foregroundStyle(BriefingColor.ink4)
                }

                if index == coordinator.stack.count - 1 {
                    currentLabel(for: destination)
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.35)) {
                            coordinator.popTo(index: index)
                        }
                    } label: {
                        Text(destination.title)
                            .font(.system(size: 11))
                            .foregroundStyle(BriefingColor.ink3)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Renders the label for the current (deepest) destination.
    ///
    /// Root destinations show a ``Menu`` for switching sections. Detail destinations show plain text.
    @ViewBuilder
    private func currentLabel(for destination: iPadNavigationDestination) -> some View {
        if iPadNavigationDestination.rootDestinations.contains(destination) {
            Menu {
                ForEach(iPadNavigationDestination.rootDestinations, id: \.title) { dest in
                    Button {
                        withAnimation(.easeOut(duration: 0.35)) {
                            coordinator.navigate(to: dest)
                        }
                    } label: {
                        Label(dest.title, systemImage: dest == destination ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(destination.title)
                        .font(.system(size: 11))
                        .foregroundStyle(BriefingColor.ink3)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(BriefingColor.ink3)
                }
            }
        } else {
            Text(destination.title)
                .font(.system(size: 11))
                .foregroundStyle(BriefingColor.ink3)
        }
    }
}
