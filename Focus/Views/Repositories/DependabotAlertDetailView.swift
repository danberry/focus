import SwiftUI

// MARK: - DependabotAlertDetailView

/// Displays detail information for a Dependabot alert, including package metadata, assignees, and code owner email actions.
struct DependabotAlertDetailView: View {

    // MARK: - Properties

    /// The Dependabot alert whose details this view displays.
    let alert: DependabotAlert

    /// The repository that owns this alert.
    let repository: SavedRepository

    /// The authentication service used to obtain tokens for code owner resolution.
    @Environment(AuthenticationService.self) private var authService

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The current email resolution state, controlling button labels and the disabled state.
    @State private var emailState: EmailState = .idle

    /// Whether the assign code owner sheet is currently presented.
    @State private var showingAssignSheet = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        List {
            // MARK: Assignees

            Section("Assignees") {
                if alert.assignedLogins.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(alert.assignedLogins, id: \.self) { login in
                        Label(login, systemImage: "person")
                    }
                }
                Button {
                    showingAssignSheet = true
                } label: {
                    Label("Manage Assignees", systemImage: "person.badge.plus")
                }
            }

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
        .sheet(isPresented: $showingAssignSheet) {
            AssignCodeOwnerView(alert: alert, repository: repository)
        }
    }

    // MARK: - Helpers

    /// Resolves code owner emails for the alert's manifest path and opens a pre-filled mailto draft.
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

/// Tracks the code owner email resolution lifecycle for the action button.
private enum EmailState: Equatable {
    /// No email action is in progress.
    case idle
    /// Code owner handles are currently being resolved to email addresses.
    case resolving
    /// Resolution completed but no public email addresses were found.
    case noEmails
}
