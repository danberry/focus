import SwiftUI

// MARK: - iPadContentView

/// The main content area of the iPad root interface, occupying the space below the navigation bar.
///
/// Root destinations scale in/out; detail destinations slide in/out from the trailing edge.
/// This encodes push/pop semantics through structural position rather than a direction flag,
/// avoiding the SwiftUI issue where removal transitions are captured before state changes fire.
struct iPadContentView: View {

    // MARK: - Properties

    /// The navigation coordinator determining which destination to display.
    let coordinator: iPadNavigationCoordinator

    // MARK: - Body

    /// The view's content.
    var body: some View {
        if coordinator.stack.count > 1, let detail = coordinator.stack.last {
            resolve(detail)
                .transition(.asymmetric(
                    insertion: .modifier(
                        active: HorizontalOffsetModifier(x: 60, opacity: 0),
                        identity: HorizontalOffsetModifier(x: 0, opacity: 1)
                    ),
                    removal: .modifier(
                        active: HorizontalOffsetModifier(x: 60, opacity: 0),
                        identity: HorizontalOffsetModifier(x: 0, opacity: 1)
                    )
                ))
        } else {
            resolve(coordinator.stack.last)
                .id(coordinator.stack.last)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
        }
    }

    // MARK: - Helpers

    /// Resolves the view for the given destination.
    @ViewBuilder
    private func resolve(_ destination: iPadNavigationDestination?) -> some View {
        switch destination {
        case .briefing:
            BriefingView(onAttentionAction: { item in
                withAnimation(.easeOut(duration: 0.35)) {
                    coordinator.push(.attentionDetail(item))
                }
            })
        case .repositories:
            ContentView()
        case .teams:
            TeamsView()
        case .reports:
            ReportsView()
        case .settings:
            SettingsView()
        case .attentionDetail(let item):
            BriefingAttentionDetailView(item: item)
        case nil:
            Color.clear
        }
    }
}

// MARK: - HorizontalOffsetModifier

/// Applies a horizontal offset and opacity, used to build subtle slide transitions.
private struct HorizontalOffsetModifier: ViewModifier {

    /// The horizontal offset in points.
    let x: CGFloat

    /// The opacity value.
    let opacity: Double

    /// The view's content.
    func body(content: Content) -> some View {
        content
            .offset(x: x)
            .opacity(opacity)
    }
}
