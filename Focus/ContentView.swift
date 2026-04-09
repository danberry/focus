import SwiftUI
import SwiftData

// MARK: - ContentView

struct ContentView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(BackgroundSyncManager.self) private var syncManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\SavedRepository.displayName, comparator: .localizedStandard)]) private var repositories: [SavedRepository]

    @State private var isAddingRepository = false
    @State private var searchText = ""

    private var filteredRepositories: [SavedRepository] {
        guard !searchText.isEmpty else { return repositories }
        let query = searchText.lowercased()
        return repositories.filter { repo in
            repo.displayName.lowercased().contains(query) ||
            (repo.primaryLanguage?.lowercased().contains(query) ?? false)
        }
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
                    ContentUnavailableView.search(text: searchText)
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
