import SwiftUI
import SwiftData

// MARK: - SecurityAlertFilter

private enum SecurityAlertFilter: String, CaseIterable, Identifiable {
    case dependabot = "Dependabot"
    case secrets = "Secrets"
    case codeScanning = "Code Scanning"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .dependabot: return "ant.fill"
        case .secrets: return "key.fill"
        case .codeScanning: return "magnifyingglass"
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
    @State private var activeFilters: Set<SecurityAlertFilter> = []

    private var filteredRepositories: [SavedRepository] {
        var result = Array(repositories)
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { repo in
                repo.displayName.lowercased().contains(query) ||
                (repo.primaryLanguage?.lowercased().contains(query) ?? false)
            }
        }
        if !activeFilters.isEmpty {
            result = result.filter { repo in
                activeFilters.contains { filter in
                    switch filter {
                    case .dependabot: return repo.dependabotAlerts > 0
                    case .secrets: return repo.secretScanningAlerts > 0
                    case .codeScanning: return repo.codeScanningAlerts > 0
                    }
                }
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                SecurityAlertFilterBar(activeFilters: $activeFilters)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
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

// MARK: - SecurityAlertFilterBar

private struct SecurityAlertFilterBar: View {
    @Binding var activeFilters: Set<SecurityAlertFilter>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SecurityAlertFilter.allCases) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        systemImage: filter.systemImage,
                        isActive: activeFilters.contains(filter)
                    ) {
                        if activeFilters.contains(filter) {
                            activeFilters.remove(filter)
                        } else {
                            activeFilters.insert(filter)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Color.accentColor : Color(.systemFill))
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
