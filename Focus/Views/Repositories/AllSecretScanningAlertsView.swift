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
        List {
            ForEach(alerts) { alert in
                HStack {
                    Text(alert.secretTypeDisplayName)
                    Spacer()
                    Text(alert.validity)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Secret Scanning Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
