import SwiftUI

// MARK: - DependabotAlertDetailView

struct DependabotAlertDetailView: View {
    let alert: DependabotAlert
    let repository: SavedRepository

    @Environment(AuthenticationService.self) private var authService

    @State private var emailState: EmailState = .idle

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

            Section {
                if let url = URL(string: alert.htmlUrl) {
                    Link(destination: url) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                    }
                }

                Button {
                    Task { await resolveAndEmail() }
                } label: {
                    switch emailState {
                    case .idle:
                        Label("Email Code Owners", systemImage: "envelope")
                    case .resolving:
                        Label("Resolving owners…", systemImage: "person.crop.circle.badge.clock")
                    case .noEmails:
                        Label("Email Code Owners", systemImage: "envelope")
                    }
                }
                .disabled(emailState == .resolving)

                if emailState == .noEmails {
                    Text("No public email addresses found for the code owners of this file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(alert.packageName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Email Resolution

    @MainActor
    private func resolveAndEmail() async {
        emailState = .resolving

        let handles = CodeownerResolver.resolve(
            filePath: alert.manifestPath ?? "",
            codeowners: repository.codeowners
        )

        let service = CodeownerEmailService(
            rest: RESTClient(tokenProvider: authService.tokenProvider)
        )
        let emails = await service.resolveEmails(
            handles: handles,
            organization: repository.owner
        )

        guard !emails.isEmpty else {
            emailState = .noEmails
            return
        }

        let draft = MailtoComposer.draft(for: alert, repository: repository, recipients: emails)
        guard let url = MailtoComposer.url(for: draft) else {
            emailState = .noEmails
            return
        }

        emailState = .idle
        await UIApplication.shared.open(url)
    }
}

// MARK: - EmailState

private enum EmailState: Equatable {
    case idle
    case resolving
    case noEmails
}
