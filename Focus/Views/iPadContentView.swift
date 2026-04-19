import SwiftUI

// MARK: - iPadContentView

/// The main content area of the iPad root interface, occupying the space below the navigation bar.
///
/// Renders the view corresponding to the topmost destination on the ``iPadNavigationCoordinator`` stack.
struct iPadContentView: View {

    // MARK: - Properties

    /// The navigation coordinator determining which destination to display.
    let coordinator: iPadNavigationCoordinator

    // MARK: - Body

    /// The view's content.
    var body: some View {
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
