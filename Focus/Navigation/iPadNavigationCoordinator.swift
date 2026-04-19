import Observation

// MARK: - iPadNavigationCoordinator

/// Manages the iPad navigation stack, tracking the sequence of destinations presented in the content area.
///
/// Owned by `MainSplitView` and injected into the view hierarchy so the navigation bar
/// and content area can stay in sync. Push a destination to navigate forward;
/// pop to go back; pop to root to reset.
@Observable
final class iPadNavigationCoordinator {

    // MARK: - Properties

    /// The ordered stack of destinations currently in the navigation hierarchy.
    ///
    /// The last element is the currently visible destination. An empty stack indicates
    /// no destination has been selected.
    var stack: [iPadNavigationDestination] = [.briefing]

    /// The title of the currently visible destination, or `nil` when the stack is empty.
    var currentTitle: String? { stack.last?.title }

    // MARK: - Navigation

    /// Pushes a new destination onto the navigation stack.
    func push(_ destination: iPadNavigationDestination) {
        stack.append(destination)
    }

    /// Removes the topmost destination from the navigation stack.
    ///
    /// Has no effect when the stack is empty.
    func pop() {
        guard !stack.isEmpty else { return }
        stack.removeLast()
    }

    /// Removes all destinations from the navigation stack.
    func popToRoot() {
        stack.removeAll()
    }

    /// Replaces the navigation stack with a single top-level destination.
    ///
    /// Use this to switch between root-level sections. To drill deeper within the
    /// current section, use ``push(_:)`` instead.
    func navigate(to destination: iPadNavigationDestination) {
        stack = [destination]
    }
}

// MARK: - iPadNavigationDestination

/// A destination that can be pushed onto the ``iPadNavigationCoordinator`` stack.
enum iPadNavigationDestination: CaseIterable {

    /// The Focus briefing dashboard.
    case briefing

    /// The repositories list.
    case repositories

    /// The teams list.
    case teams

    /// The reports dashboard.
    case reports

    /// The settings screen.
    case settings

    // MARK: - Properties

    /// The display title for this destination, shown in the navigation hierarchy.
    var title: String {
        switch self {
        case .briefing:      "The Brief"
        case .repositories:  "Repositories"
        case .teams:         "Teams"
        case .reports:       "Reports"
        case .settings:      "Settings"
        }
    }
}
