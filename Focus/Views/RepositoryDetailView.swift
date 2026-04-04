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

            Section("Security Alerts") {
                LabeledContent("Dependabot", value: "\(repository.dependabotAlerts)")
                LabeledContent("Code Scanning", value: "\(repository.codeScanningAlerts)")
                LabeledContent("Secret Scanning", value: "\(repository.secretScanningAlerts)")
            }
        }
        .navigationTitle(repository.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
