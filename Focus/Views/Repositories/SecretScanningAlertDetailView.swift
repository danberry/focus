import SwiftUI

// MARK: - SecretScanningAlertDetailView

/// Displays detail information for a single secret scanning alert.
struct SecretScanningAlertDetailView: View {

    // MARK: - Properties

    /// The secret scanning alert to display.
    let alert: SecretScanningAlert

    // MARK: - Body

    /// The view's content.
    var body: some View {
        List {
            // MARK: Overview

            Section("Overview") {
                LabeledContent("Secret Type", value: alert.secretTypeDisplayName)
                LabeledContent("Validity", value: alert.validity.capitalized)
                LabeledContent("Alert Number", value: "#\(alert.alertNumber)")
            }

            // MARK: Details

            Section("Details") {
                LabeledContent("Created", value: alert.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Days Open", value: "\(Calendar.current.dateComponents([.day], from: alert.createdAt, to: .now).day ?? 0)")
                LabeledContent("Publicly Leaked", value: alert.publiclyLeaked ? "Yes" : "No")
                LabeledContent("Multi-Repo", value: alert.multiRepo ? "Yes" : "No")
                if alert.pushProtectionBypassed {
                    LabeledContent("Push Protection", value: "Bypassed")
                }
            }

            // MARK: Actions

            Section {
                if let url = URL(string: alert.htmlUrl), !alert.htmlUrl.isEmpty {
                    Link(destination: url) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(alert.secretTypeDisplayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
