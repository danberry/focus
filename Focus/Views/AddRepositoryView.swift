import SwiftUI
import SwiftData

// MARK: - AddRepositoryView

struct AddRepositoryView: View {
    let repositoryService: RepositoryService
    let securityService: SecurityService
    let codeownersService: CodeownersService
    let velocityService: VelocityService
    let pullRequestService: PullRequestService

    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var owner = ""
    @State private var repoName = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var error: GitHubError?
    @State private var showTokenEntry = false

    private var canSubmit: Bool {
        !owner.trimmingCharacters(in: .whitespaces).isEmpty &&
        !repoName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. My Swift Repo", text: $displayName)
                } header: {
                    Text("Display Name")
                }

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
            .sheet(isPresented: $showTokenEntry) {
                LoginView()
            }
            .onChange(of: showTokenEntry) { _, isPresenting in
                guard !isPresenting, authService.authState == .authenticated else { return }
                Task { await save() }
            }
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
        let trimmedOwner = owner.trimmingCharacters(in: .whitespaces)
        let trimmedName = repoName.trimmingCharacters(in: .whitespaces)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)

        guard authService.authState == .authenticated else {
            showTokenEntry = true
            return
        }

        isLoading = true
        error = nil

        do {
            let repo = try await repositoryService.fetchRepository(owner: trimmedOwner, name: trimmedName)
            let metrics = await securityService.fetchMetrics(owner: trimmedOwner, repo: trimmedName)
            let saved = SavedRepository(
                githubId: repo.id,
                owner: trimmedOwner,
                name: repo.name,
                displayName: trimmedDisplayName,
                repoDescription: repo.description,
                primaryLanguage: repo.primaryLanguage?.name,
                dependabotAlerts: metrics.dependabotAlerts ?? 0,
                codeScanningAlerts: metrics.codeScanningAlerts ?? 0,
                secretScanningAlerts: metrics.secretScanningAlerts ?? 0
            )
            modelContext.insert(saved)

            await securityService.syncDependabotAlerts(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await securityService.syncCodeScanningAlerts(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await securityService.syncSecretScanningAlerts(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await codeownersService.syncCodeowners(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await velocityService.syncVelocity(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await pullRequestService.syncOpenPullRequests(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)

            dismiss()
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }
}
