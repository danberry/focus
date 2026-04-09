import SwiftUI
import SwiftData

// MARK: - AddOrganizationView

struct AddOrganizationView: View {
    let organizationService: OrganizationService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var login = ""
    @State private var isLoading = false
    @State private var error: GitHubError?

    private var canSubmit: Bool {
        !login.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

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

    // MARK: - Private

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
