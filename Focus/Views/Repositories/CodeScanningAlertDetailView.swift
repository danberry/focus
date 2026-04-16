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
                if let ruleId = alert.ruleId {
                    LabeledContent("Rule ID", value: ruleId)
                }
                if let severity = alert.securitySeverityLevel {
                    LabeledContent("Severity", value: severity.capitalized)
                }
                if let toolName = alert.toolName {
                    LabeledContent("Tool", value: toolName)
                }
                LabeledContent("Alert", value: "#\(alert.alertNumber)")
            }

            // MARK: Finding

            if let messageText = alert.messageText {
                Section("Finding") {
                    Text(messageText)
                        .font(.callout)
                }
            }

            // MARK: Location

            if let path = alert.locationPath {
                Section("Location") {
                    if let line = alert.locationStartLine {
                        LabeledContent("File", value: "\(path):\(line)")
                    } else {
                        LabeledContent("File", value: path)
                    }
                }
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
