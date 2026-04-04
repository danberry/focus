import SwiftUI
import SwiftData

// MARK: - ContentView

struct ContentView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedRepository.name) private var repositories: [SavedRepository]

    @State private var isAddingRepository = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(repositories) { repo in
                    SavedRepositoryRow(repository: repo)
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Repositories")
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
                    )
                )
            }
        }
    }

    // MARK: - Private

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
            Text(repository.name)
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
