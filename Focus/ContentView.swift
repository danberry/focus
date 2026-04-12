import SwiftUI
import SwiftData

// MARK: - SecurityAlertFilter

private enum SecurityAlertFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "Repositories"
    case codeScanning = "Code Scanning"
    case dependabot = "Dependabot"
    case secrets = "Secrets"

    var id: Self { self }

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

struct ContentView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(BackgroundSyncManager.self) private var syncManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\SavedRepository.displayName, comparator: .localizedStandard)]) private var repositories: [SavedRepository]

    @State private var isAddingRepository = false
    @State private var searchText = ""
    @State private var activeFilter: SecurityAlertFilter = .all
    
    private var foregroundColor: Color {
        if activeFilter != .all {
            Color(.systemBackground)
        }
        else {
            Color.primary
        }
    }

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

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredRepositories) { repo in
                    NavigationLink(destination: RepositoryDetailView(repository: repo)) {
                        SavedRepositoryRow(repository: repo)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
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
                    )
                )
            }
        }
    }

    // MARK: - Private

    private var syncSubtitle: String {
        if syncManager.isSyncing {
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

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRepositories[index])
        }
    }
}

// MARK: - SavedRepositoryRow

private struct SavedRepositoryRow: View {
    let repository: SavedRepository

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
        .modelContainer(for: SavedRepository.self, inMemory: true)
}
