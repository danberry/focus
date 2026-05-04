import SwiftUI

// MARK: - AllSecretScanningAlertsView

/// Displays a list of secret scanning alerts for a repository.
struct AllSecretScanningAlertsView: View {

    // MARK: - Properties

    /// The secret scanning alerts to display.
    let alerts: [SecretScanningAlert]

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Group {
            if alerts.isEmpty {
                EmptyContentView("No Secret Scanning Alerts", systemImage: "checkmark.shield")
            } else {
                List {
                    ForEach(alerts) { alert in
                        NavigationLink(destination: SecretScanningAlertDetailView(alert: alert)) {
                            LabeledContent(alert.secretTypeDisplayName, value: alert.validity)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Secret Scanning Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
