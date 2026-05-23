import SwiftUI
import SwiftData

// MARK: - AddRepositoryView

/// A form for searching for and adding a new GitHub repository to the watch list.
struct AddRepositoryView: View {

    // MARK: - Properties

    /// The service used to fetch repository metadata from GitHub.
    let repositoryService: RepositoryService

    /// The service used to fetch and sync security alert data.
    let securityService: SecurityService

    /// The service used to sync CODEOWNERS data.
    let codeownersService: CodeownersService

    /// The service used to sync velocity metrics.
    let velocityService: VelocityService

    /// The service used to sync open pull requests.
    let pullRequestService: PullRequestService

    /// The service used to sync recent releases.
    let releaseService: ReleaseService

    /// The authentication service, providing the current auth state.
    @Environment(AuthenticationService.self) private var authService

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The dismiss action for closing this sheet.
    @Environment(\.dismiss) private var dismiss

    /// The GitHub organization or user login entered by the user.
    @State private var owner = ""

    /// The repository name entered by the user.
    @State private var repoName = ""

    /// The display name label entered by the user.
    @State private var displayName = ""

    /// Whether a network request is currently in progress.
    @State private var isLoading = false

    /// The most recent error returned from the add-repository flow, or `nil` if none.
    @State private var error: GitHubError?

    /// Whether the token-entry sheet is currently presented.
    @State private var showTokenEntry = false

    /// Returns `true` when all required fields are non-empty and no request is in flight.
    private var canSubmit: Bool {
        !owner.trimmingCharacters(in: .whitespaces).isEmpty &&
        !repoName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isLoading
    }

    // MARK: - Body

    /// The view's content.
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

    // MARK: - Helpers

    /// Validates inputs, fetches the repository, and persists it along with all associated data.
    @MainActor
    private func save() async {
        let trimmedOwner = owner.trimmingCharacters(in: .whitespaces)
        let trimmedName = repoName.trimmingCharacters(in: .whitespaces)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)

        guard authService.authState == .authenticated else {
            showTokenEntry = true
            return
        }

        let duplicateDescriptor = FetchDescriptor<SavedRepository>(
            predicate: #Predicate { $0.owner == trimmedOwner && $0.name == trimmedName }
        )
        if let existing = try? modelContext.fetch(duplicateDescriptor), !existing.isEmpty {
            error = .repositoryAlreadySaved
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
                primaryLanguage: repo.primaryLanguage?.name
            )
            saved.repositoryDescription = repo.description
            saved.isPrivate = repo.isPrivate
            modelContext.insert(saved)

            await securityService.syncAllDependabotAlerts(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await securityService.syncAllCodeScanningAlerts(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await securityService.syncAllSecretScanningAlerts(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await codeownersService.syncCodeowners(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await velocityService.syncVelocity(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await pullRequestService.syncOpenPullRequests(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)
            await releaseService.syncReleases(owner: trimmedOwner, repo: trimmedName, repository: saved, in: modelContext)

            dismiss()
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }
}
