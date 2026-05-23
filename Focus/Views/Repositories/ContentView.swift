import SwiftUI
import SwiftData

// MARK: - SecurityAlertFilter

/// A filter type for narrowing the repository list by security alert category.
private enum SecurityAlertFilter: String, CaseIterable, Identifiable, Hashable {
    /// Shows all repositories regardless of alert status.
    case all = "Repositories"
    /// Filters to repositories with open code scanning alerts.
    case codeScanning = "Code Scanning"
    /// Filters to repositories with open Dependabot alerts.
    case dependabot = "Dependabot"
    /// Filters to repositories with open secret scanning alerts.
    case secrets = "Secrets"

    /// The stable identity value for this filter.
    var id: Self { self }

    /// The SF Symbol name representing this filter in the toolbar menu.
    var systemImage: String {
        switch self {
        case .all: "server.rack"
        case .dependabot: "ant"
        case .secrets: "key"
        case .codeScanning: "eyeglasses"
        }
    }
}

// MARK: - ContentView

/// Displays the list of saved repositories with search and security alert filtering.
struct ContentView: View {

    // MARK: - Properties

    /// The authentication service, used to provide token access when presenting the add-repository sheet.
    @Environment(AuthenticationService.self) private var authService
    /// The background sync manager, used to populate the navigation subtitle with sync status.
    @Environment(BackgroundSyncManager.self) private var syncManager
    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext
    /// All saved repositories, sorted alphabetically by display name.
    @Query(sort: [SortDescriptor(\SavedRepository.displayName, comparator: .localizedStandard)]) private var repositories: [SavedRepository]
    /// Controls whether the add-repository sheet is presented.
    @State private var isAddingRepository = false
    /// The current search query entered by the user.
    @State private var searchText = ""
    /// The active security alert filter applied to the repository list.
    @State private var activeFilter: SecurityAlertFilter = .all
    /// The repository whose detail view is being pushed from the context menu, or `nil` when none is shown.
    @State private var detailRepository: SavedRepository?

    // MARK: - Body

    /// The view's content.
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredRepositories) { repo in
                    NavigationLink(destination: RepositoryDossierView(dossier: RepositoryDossier(repository: repo))) {
                        SavedRepositoryRow(repository: repo)
                    }
                    .contextMenu {
                        Button("View Details", systemImage: "info.circle") {
                            detailRepository = repo
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
            .refreshable {
                await syncManager.syncNow(context: modelContext)
            }
            .searchable(text: $searchText, prompt: "Search by name or language")
            .navigationTitle("Repositories")
            .navigationSubtitle(syncSubtitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(selection: $activeFilter) {
                            ForEach(SecurityAlertFilter.allCases) { filter in
                                Label(
                                    filter.rawValue,
                                    systemImage: filter.systemImage
                                )
                                .tag(filter)
                            }
                        } label: {}
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(6)
                            .background(activeFilter != .all ? .accent : .clear)
                            .clipShape(.circle)
                            .foregroundStyle(foregroundColor)
                    }
                }

                ToolbarSpacer(.fixed, placement: .topBarTrailing)

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") {
                        isAddingRepository = true
                    }
                }
            }
            .overlay {
                if repositories.isEmpty {
                    ContentUnavailableView(
                        "No Saved Repositories",
                        systemImage: "bookmark.slash",
                        description: Text("Tap + to add a repository.")
                    )
                } else if filteredRepositories.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView(
                            "No Matching Repositories",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("No repositories have the selected alert types.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .navigationDestination(item: $detailRepository) { repo in
                RepositoryDetailView(repository: repo)
            }
            .sheet(isPresented: $isAddingRepository) {
                AddRepositoryView(
                    repositoryService: RepositoryService(
                        graphQL: GraphQLClient(tokenProvider: authService.tokenProvider)
                    ),
                    securityService: SecurityService(
                        rest: RESTClient(tokenProvider: authService.tokenProvider)
                    ),
                    codeownersService: CodeownersService(
                        rest: RESTClient(tokenProvider: authService.tokenProvider)
                    ),
                    velocityService: VelocityService(
                        graphQL: GraphQLClient(tokenProvider: authService.tokenProvider)
                    ),
                    pullRequestService: PullRequestService(
                        graphQL: GraphQLClient(tokenProvider: authService.tokenProvider)
                    ),
                    releaseService: ReleaseService(
                        graphQL: GraphQLClient(tokenProvider: authService.tokenProvider)
                    )
                )
            }
        }
    }

    // MARK: - Helpers

    /// The foreground color for the filter icon, contrasting against the active filter background.
    private var foregroundColor: Color {
        if activeFilter != .all {
            Color(.systemBackground)
        }
        else {
            Color.primary
        }
    }

    /// The repositories that match the current search text and active alert filter.
    private var filteredRepositories: [SavedRepository] {
        var result = Array(repositories)
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { repo in
                repo.displayName.lowercased().contains(query) ||
                (repo.primaryLanguage?.lowercased().contains(query) ?? false)
            }
        }

        result = result.filter { repo in
            switch activeFilter {
            case .all:
                true
            case .dependabot:
                repo.dependabotAlerts > 0
            case .secrets:
                repo.secretScanningAlerts > 0
            case .codeScanning:
                repo.codeScanningAlerts > 0
            }
        }

        return result
    }

    /// Returns a subtitle reflecting the current sync state for the navigation bar.
    private var syncSubtitle: String {
        if syncManager.isSyncing {
            let total = syncManager.syncTotal
            let current = syncManager.syncCurrent
            if total > 0 && current > 0 {
                return "Loading \(current)/\(total)"
            }
            return "Loading..."
        }
        guard let date = syncManager.lastSyncedAt else {
            return ""
        }
        if Calendar.current.isDateInToday(date) {
            return "Last updated • " + date.formatted(date: .omitted, time: .shortened)
        } else {
            return "Last updated • " + date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
    }

    /// Deletes saved repositories at the given index set from the model context.
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRepositories[index])
        }
    }
}

// MARK: - SavedRepositoryRow

/// A list row displaying a saved repository's name, language, and total security alert count.
struct SavedRepositoryRow: View {

    // MARK: - Properties

    /// The repository to display.
    let repository: SavedRepository

    // MARK: - Body

    /// The view's content.
    var body: some View {
        LabeledContent {
            Text("\(repository.totalSecurityAlerts)")
        } label: {
            Text(repository.displayName)
            if let language = repository.primaryLanguage {
                Text(language)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SavedRepository.self], inMemory: true)
}
