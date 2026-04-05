import SwiftUI
import SwiftData

// MARK: - AddMemberView

struct AddMemberView: View {
    let team: Team
    let restClient: RESTClient
    let contributionService: ContributionService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var githubLogin = ""
    @State private var isLoading = false
    @State private var error: GitHubError?

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    private var errorMessage: String {
        guard let error else { return "" }
        if case .notFound = error {
            return "No GitHub user found with that login."
        }
        return error.localizedDescription
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Jane Smith", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    TextField("e.g. janesmith", text: $githubLogin)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("GitHub Login")
                } footer: {
                    Text("Optional. If provided, will be validated against GitHub.")
                }

                if error != nil {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Member")
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
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedLogin = githubLogin.trimmingCharacters(in: .whitespaces)

        isLoading = true
        error = nil

        do {
            var githubId: Int?
            if !trimmedLogin.isEmpty {
                let lookup: GitHubUserID = try await restClient.get(
                    path: Endpoint.userProfile(login: trimmedLogin).path
                )
                githubId = lookup.id
            }
            let member = Member(
                name: trimmedName,
                githubId: githubId,
                githubLogin: trimmedLogin.isEmpty ? nil : trimmedLogin
            )
            member.team = team
            modelContext.insert(member)

            if !trimmedLogin.isEmpty {
                await contributionService.syncContributions(
                    login: trimmedLogin,
                    member: member,
                    in: modelContext
                )
            }

            dismiss()
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }
}

// MARK: - GitHubUserID

private struct GitHubUserID: Decodable {
    let id: Int
}
