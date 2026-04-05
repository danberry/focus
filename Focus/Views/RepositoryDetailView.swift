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
                // Placeholder — Task 2 replaces this
                Text("No open alerts")
                    .foregroundStyle(.secondary)
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
