import SwiftUI

// MARK: - AllCodeScanningAlertsView

/// Displays a list of code scanning alerts for a repository.
struct AllCodeScanningAlertsView: View {

    // MARK: - Properties

    /// The code scanning alerts to display.
    let alerts: [CodeScanningAlert]

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Group {
            if alerts.isEmpty {
                EmptyContentView("No Code Scanning Alerts", systemImage: "checkmark.shield")
            } else {
                List {
                    ForEach(alerts) { alert in
                        NavigationLink(destination: CodeScanningAlertDetailView(alert: alert)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.ruleName)
                                if let severity = alert.securitySeverityLevel {
                                    Text(severity)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Code Scanning Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
