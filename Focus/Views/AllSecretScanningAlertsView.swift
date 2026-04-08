import SwiftUI

// MARK: - AllSecretScanningAlertsView

struct AllSecretScanningAlertsView: View {
    let alerts: [SecretScanningAlert]

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
