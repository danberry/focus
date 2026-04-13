import SwiftUI
import SwiftData

// MARK: - AddMemberView

/// A form for adding a new member to a team.
struct AddMemberView: View {

    // MARK: - Properties

    /// The team the new member will be added to.
    let team: Team

    /// The REST client used to validate GitHub logins.
    let restClient: RESTClient

    /// The service used to sync contribution data for the new member.
    let contributionService: ContributionService

    /// The authentication service, used to check login state before making GitHub API calls.
    @Environment(AuthenticationService.self) private var authService

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The dismiss action for closing this sheet.
    @Environment(\.dismiss) private var dismiss

    /// All available job titles, sorted alphabetically by name.
    @Query(sort: \JobTitle.name) private var allJobTitles: [JobTitle]

    /// The display name entered by the user.
    @State private var name = ""

    /// The GitHub login entered by the user.
    @State private var githubLogin = ""

    /// The job title selected for the new member.
    @State private var selectedJobTitle: JobTitle?

    /// Whether the save operation is in progress.
    @State private var isLoading = false

    /// The most recent GitHub API error, or `nil` if no error has occurred.
    @State private var error: GitHubError?

    /// Whether the token entry sheet is presented.
    @State private var showTokenEntry = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Jane Smith", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    Picker("Job Title", selection: $selectedJobTitle) {
                        Text("None").tag(Optional<JobTitle>.none)
                        ForEach(allJobTitles) { title in
                            Text(title.name).tag(Optional(title))
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Job Title")
                } footer: {
                    Text("Optional. Select from job titles defined in Disciplines.")
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

    /// Whether the form is in a valid state to be submitted.
    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    /// A human-readable description of the current error, or an empty string if there is none.
    private var errorMessage: String {
        guard let error else { return "" }
        if case .notFound = error {
            return "No GitHub user found with that login."
        }
        return error.localizedDescription
    }

    /// Validates the form input, optionally resolves the GitHub user ID, inserts the new member, and dismisses the sheet.
    ///
    /// If a GitHub login is provided but the user is unauthenticated, presents the token entry sheet
    /// and retries after authentication. Unknown errors are mapped to ``GitHubError/networkError(underlying:)``.
    @MainActor
    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedLogin = githubLogin.trimmingCharacters(in: .whitespaces)

        if !trimmedLogin.isEmpty, authService.authState != .authenticated {
            showTokenEntry = true
            return
        }

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
            member.jobTitle = selectedJobTitle
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

/// A minimal GitHub user response used to look up a user's numeric ID by login.
private struct GitHubUserID: Decodable {

    /// The GitHub user's numeric identifier.
    let id: Int
}
