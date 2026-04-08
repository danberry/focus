import SwiftUI

// MARK: - AllCodeScanningAlertsView

struct AllCodeScanningAlertsView: View {
    let alerts: [CodeScanningAlert]

    var body: some View {
        List {
            ForEach(alerts) { alert in
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
        .listStyle(.plain)
        .navigationTitle("Code Scanning Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
