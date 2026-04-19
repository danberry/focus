import SwiftUI

// MARK: - iPadContentView

/// The main content area of the iPad root interface, occupying the space below the navigation bar.
///
/// Renders the view corresponding to the topmost destination on the ``iPadNavigationCoordinator`` stack.
/// When the root destination changes, the incoming content fades in with a subtle scale-up effect.
struct iPadContentView: View {

    // MARK: - Properties

    /// The navigation coordinator determining which destination to display.
    let coordinator: iPadNavigationCoordinator

    // MARK: - Body

    /// The view's content.
    var body: some View {
        content
            .id(coordinator.stack.last)
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
    }

    // MARK: - Helpers

    /// Resolves the view for the current top of the navigation stack.
    @ViewBuilder
    private var content: some View {
        switch coordinator.stack.last {
        case .briefing:
            BriefingView()
        case .repositories:
            ContentView()
        case .teams:
            TeamsView()
        case .reports:
            ReportsView()
        case .settings:
            SettingsView()
        case nil:
            Color.clear
        }
    }
}
