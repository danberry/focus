import SwiftUI

// MARK: - CodeScanningAlertDetailView

/// Displays details for a single code scanning alert.
struct CodeScanningAlertDetailView: View {

    // MARK: - Properties

    /// The code scanning alert to display.
    let alert: CodeScanningAlert

    // MARK: - Body

    /// The view's content.
    var body: some View {
        List {
            // MARK: Overview

            Section("Overview") {
                LabeledContent("Rule", value: alert.ruleName)
                if let severity = alert.securitySeverityLevel {
                    LabeledContent("Severity", value: severity.capitalized)
                }
                LabeledContent("Alert Number", value: "#\(alert.alertNumber)")
            }

            // MARK: Details

            Section("Details") {
                LabeledContent("Created", value: alert.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Days Open", value: "\(Calendar.current.dateComponents([.day], from: alert.createdAt, to: .now).day ?? 0)")
            }

            // MARK: Actions

            Section {
                if let url = URL(string: alert.htmlUrl) {
                    Link(destination: url) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(alert.ruleName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
