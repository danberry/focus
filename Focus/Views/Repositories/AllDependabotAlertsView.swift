import SwiftUI

// MARK: - AllDependabotAlertsView

/// Displays all Dependabot alerts for a repository in a navigable list.
struct AllDependabotAlertsView: View {

    // MARK: - Properties

    /// The Dependabot alerts to display.
    let alerts: [DependabotAlert]

    /// The repository these alerts belong to.
    let repository: SavedRepository

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Group {
            if alerts.isEmpty {
                EmptyContentView("No Dependabot Alerts", systemImage: "checkmark.shield")
            } else {
                List {
                    ForEach(alerts) { alert in
                        NavigationLink(destination: DependabotAlertDetailView(alert: alert, repository: repository)) {
                            LabeledContent(alert.packageName, value: alert.severity)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Dependabot Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
