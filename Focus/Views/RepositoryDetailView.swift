import SwiftUI
import SwiftData

// MARK: - RepositoryDetailView

struct RepositoryDetailView: View {
    let repository: SavedRepository

    var body: some View {
        List {
            // MARK: Info

            Section("Info") {
                LabeledContent("Owner", value: repository.owner)
                LabeledContent("Name", value: repository.name)
                LabeledContent("Language", value: repository.primaryLanguage ?? "None")
            }

            // MARK: Security Alerts

            Section("Dependabot Alerts") {
                if repository.dependabotAlertDetails.isEmpty {
                    Text("No open alerts")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(repository.dependabotAlertDetails.sorted { $0.createdAt < $1.createdAt }) { alert in
                        NavigationLink(destination: DependabotAlertDetailView(alert: alert)) {
                            LabeledContent(alert.packageName, value: alert.severity)
                        }
                    }
                }
            }

            Section("Code Scanning Alerts") {
                let sorted = repository.codeScanningAlertDetails.sorted { $0.createdAt < $1.createdAt }
                if sorted.isEmpty {
                    Text("No open alerts")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sorted) { alert in
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

            Section("Secret Scanning Alerts") {
                let sorted = repository.secretScanningAlertDetails.sorted { $0.createdAt < $1.createdAt }
                if sorted.isEmpty {
                    Text("No open alerts")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sorted) { alert in
                        HStack {
                            Text(alert.secretTypeDisplayName)
                            Spacer()
                            Text(alert.validity)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(repository.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
