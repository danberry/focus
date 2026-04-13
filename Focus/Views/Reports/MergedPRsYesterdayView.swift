import SwiftUI
import SwiftData

// MARK: - MergedPRsYesterdayView

/// Displays a report of pull requests merged across all watched repositories yesterday.
struct MergedPRsYesterdayView: View {

    // MARK: - Properties

    /// The authentication service used to obtain a token for API requests.
    @Environment(AuthenticationService.self) private var authService

    /// All repositories the user has saved, sorted alphabetically by display name.
    @Query(sort: \SavedRepository.displayName) private var savedRepositories: [SavedRepository]

    /// Whether a data load is currently in progress.
    @State private var isLoading = false

    /// The most recent error returned by the data load, or `nil` if the last load succeeded.
    @State private var error: GitHubError?

    /// Merged PRs keyed by `owner/repo` slug.
    @State private var prsByRepo: [String: [MergedPR]] = [:]

    /// All merged PRs across every repository, flattened into a single array.
    private var allPRs: [MergedPR] { prsByRepo.values.flatMap { $0 } }

    /// Yesterday's date in UTC.
    private var yesterday: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(byAdding: .day, value: -1, to: Date())!
    }

    /// A formatted long-style date string for yesterday, used as the navigation subtitle detail.
    private var dateSubtitle: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .none
        return fmt.string(from: yesterday)
    }

    /// A lookup from lowercased `owner/repo` slug to the user-facing display name.
    private var displayNameByRepo: [String: String] {
        Dictionary(uniqueKeysWithValues: savedRepositories.map { ("\($0.owner)/\($0.name)".lowercased(), $0.displayName) })
    }

    /// Per-repository sections sorted alphabetically by display name, with each section's PRs sorted by merge time.
    private var repoSections: [(repoName: String, prs: [MergedPR])] {
        let lookup = displayNameByRepo
        return prsByRepo
            .map { (repoName: lookup[$0.key.lowercased()] ?? $0.key, prs: $0.value.sorted { $0.mergedAt < $1.mergedAt }) }
            .sorted { $0.repoName < $1.repoName }
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Group {
            if isLoading && allPRs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView(
                    "Unable to Load Report",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else if allPRs.isEmpty {
                EmptyContentView(
                    "No Merged PRs",
                    named: "custom.point.topright.arrow.triangle.backward.to.point.bottomleft.filled.scurvepath.slash"
                )
            } else {
                List {
                    CardRow {
                        LabeledContent {} label: {
                            Text(allPRs.count, format: .number)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                            Text(dateSubtitle)
                                .textCase(.uppercase)
                        }
                    }

                    ForEach(repoSections, id: \.repoName) { section in
                        NavigationLink(destination: RepoMergedPRsListView(repoName: section.repoName, prs: section.prs)) {
                            LabeledContent(section.repoName) {
                                Text("\(section.prs.count)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await loadData() }
            }
        }
        .navigationTitle("Merged PRs")
        .navigationSubtitle("Yesterday")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Helpers

    /// Fetches merged PRs for all saved repositories on yesterday's date and updates view state.
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
            prsByRepo = try await service.fetchMergedPRs(for: repos, on: yesterday)
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }
}

// MARK: - RepoMergedPRsListView

/// Displays a list of merged pull requests for a single repository, each linking to the PR on GitHub.
private struct RepoMergedPRsListView: View {

    // MARK: - Properties

    /// The display name of the repository whose PRs are shown.
    let repoName: String

    /// The pull requests to display, in the order provided by the caller.
    let prs: [MergedPR]

    /// The environment action used to open a PR URL in the default browser.
    @Environment(\.openURL) private var openURL

    // MARK: - Body

    /// The view's content.
    var body: some View {
        List(prs) { pr in
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
        .navigationTitle(repoName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
