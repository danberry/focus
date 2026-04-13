import SwiftUI
import SwiftData

// MARK: - AddOrganizationView

/// Presents a form for adding a new GitHub organization to the user's saved list.
struct AddOrganizationView: View {

    // MARK: - Properties

    /// The service used to validate and fetch the organization from GitHub.
    let organizationService: OrganizationService

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The dismiss action, used to close this sheet on success or cancellation.
    @Environment(\.dismiss) private var dismiss

    /// The organization login name entered by the user.
    @State private var login = ""

    /// Whether a network request is currently in progress.
    @State private var isLoading = false

    /// The most recent error returned by the organization fetch, or `nil` if none.
    @State private var error: GitHubError?

    /// Whether the form can be submitted, requiring a non-empty login and no active request.
    private var canSubmit: Bool {
        !login.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. apple", text: $login)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: login) { error = nil }
                } header: {
                    Text("Organization Login")
                } footer: {
                    Text("Enter the GitHub organization login name (e.g. \"apple\" for github.com/apple).")
                }

                if let error {
                    Section {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Organization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .disabled(isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button(role: .confirm) {
                            Task { await save() }
                        }
                        .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Validates the login, fetches the organization from GitHub, and persists it to SwiftData.
    @MainActor
    private func save() async {
        let trimmedLogin = login.trimmingCharacters(in: .whitespaces)

        isLoading = true
        error = nil

        do {
            let org = try await organizationService.fetchOrganization(login: trimmedLogin)
            let saved = SavedOrganization(
                githubId: org.id,
                login: org.login,
                name: org.name,
                avatarUrl: org.avatarUrl,
                organizationDescription: org.description
            )
            modelContext.insert(saved)
            dismiss()
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }
}
