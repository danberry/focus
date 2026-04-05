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
                // Placeholder — Task 1 replaces this
                Text("No open alerts")
                    .foregroundStyle(.secondary)
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
                // Placeholder — Task 3 replaces this
                Text("No open alerts")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(repository.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
