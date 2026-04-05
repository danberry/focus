import SwiftUI

// MARK: - DependabotAlertDetailView

struct DependabotAlertDetailView: View {
    let alert: DependabotAlert

    var body: some View {
        List {
            // MARK: Overview

            Section("Overview") {
                LabeledContent("Package", value: alert.packageName)
                LabeledContent("Ecosystem", value: alert.ecosystem)
                LabeledContent("Severity", value: alert.severity.capitalized)
            }

            // MARK: Versions

            Section("Versions") {
                if let fixVersion = alert.fixVersion {
                    LabeledContent("Fixed In", value: fixVersion)
                }
            }

            // MARK: Details

            Section("Details") {
                LabeledContent("Created", value: alert.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Days Open", value: "\(Calendar.current.dateComponents([.day], from: alert.createdAt, to: .now).day ?? 0)")
            }

            // MARK: Actions

            if let url = URL(string: alert.htmlUrl) {
                Section {
                    Link(destination: url) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
        .navigationTitle(alert.packageName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
