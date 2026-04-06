import SwiftUI
import SwiftData

// MARK: - ContentView

struct ContentView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(BackgroundSyncManager.self) private var syncManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedRepository.displayName) private var repositories: [SavedRepository]

    @State private var isAddingRepository = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(repositories) { repo in
                    NavigationLink(destination: RepositoryDetailView(repository: repo)) {
                        SavedRepositoryRow(repository: repo)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
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
            modelContext.delete(repositories[index])
        }
    }
}

// MARK: - SavedRepositoryRow

private struct SavedRepositoryRow: View {
    let repository: SavedRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(repository.displayName)
                .font(.body)
            if let language = repository.primaryLanguage {
                Text(language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .badge(repository.totalSecurityAlerts)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedRepository.self, inMemory: true)
}
