import SwiftUI
import SwiftData

// MARK: - AddRepositoryView

struct AddRepositoryView: View {
    let repositoryService: RepositoryService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var owner = ""
    @State private var repoName = ""
    @State private var isLoading = false
    @State private var error: GitHubError?

    private var canSubmit: Bool {
        !owner.trimmingCharacters(in: .whitespaces).isEmpty &&
        !repoName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. apple", text: $owner)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Owner")
                }

                Section {
                    TextField("e.g. swift", text: $repoName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Repository Name")
                }

                if let error {
                    Section {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Repository")
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

    private func save() async {
        let trimmedOwner = owner.trimmingCharacters(in: .whitespaces)
        let trimmedName = repoName.trimmingCharacters(in: .whitespaces)

        isLoading = true
        error = nil

        do {
            let repo = try await repositoryService.fetchRepository(owner: trimmedOwner, name: trimmedName)
            let saved = SavedRepository(
                githubId: repo.id,
                name: repo.name,
                primaryLanguage: repo.primaryLanguage?.name
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
