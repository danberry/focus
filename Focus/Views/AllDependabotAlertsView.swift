import SwiftUI

// MARK: - AllDependabotAlertsView

struct AllDependabotAlertsView: View {
    let alerts: [DependabotAlert]
    let repository: SavedRepository

    var body: some View {
        List {
            ForEach(alerts) { alert in
                NavigationLink(destination: DependabotAlertDetailView(alert: alert, repository: repository)) {
                    LabeledContent(alert.packageName, value: alert.severity)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Dependabot Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
