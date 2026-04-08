import SwiftUI
import SwiftData

// MARK: - MergedPRsYesterdayView

struct MergedPRsYesterdayView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.openURL) private var openURL
    @Query(sort: \SavedRepository.displayName) private var savedRepositories: [SavedRepository]

    @State private var isLoading = false
    @State private var error: GitHubError?
    @State private var sections: [(repoName: String, displayName: String, prs: [MergedPR])] = []

    private var yesterday: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(byAdding: .day, value: -1, to: Date())!
    }

    private var navigationTitle: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .none
        return "Merged PRs — \(fmt.string(from: yesterday))"
    }

    var body: some View {
        Group {
            if isLoading && sections.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView(
                    "Unable to Load Report",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else if sections.isEmpty {
                ContentUnavailableView(
                    "No Merged PRs",
                    systemImage: "checkmark.circle",
                    description: Text("No pull requests were merged yesterday across your saved repositories.")
                )
            } else {
                List {
                    ForEach(sections, id: \.repoName) { section in
                        Section(section.displayName) {
                            ForEach(section.prs) { pr in
                                Button {
                                    if let url = URL(string: pr.url) {
                                        openURL(url)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pr.title)
                                            .lineLimit(1)
                                            .foregroundStyle(Color.primary)
                                        Text("by @\(pr.authorLogin) • #\(pr.number)")
                                            .font(.caption)
                                            .foregroundStyle(Color.secondary)
                                    }
                                }

                            }
                        }
                    }
                }
                .refreshable { await loadData() }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Private

    @MainActor
    private func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        let service = MergedPRReportService(
            graphQL: GraphQLClient(tokenProvider: authService.tokenProvider)
        )

        do {
            let repos = savedRepositories.map { (owner: $0.owner, name: $0.name) }
            let displayNames = Dictionary(
                uniqueKeysWithValues: savedRepositories.map { ("\($0.owner)/\($0.name)".lowercased(), $0.displayName) }
            )
            let prsByRepo = try await service.fetchMergedPRs(for: repos, on: yesterday)
            sections = prsByRepo
                .map { (repoName: $0.key, displayName: displayNames[$0.key.lowercased()] ?? $0.key, prs: $0.value) }
                .sorted { $0.displayName < $1.displayName }
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }
}
