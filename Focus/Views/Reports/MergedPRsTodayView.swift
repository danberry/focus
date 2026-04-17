import SwiftUI
import SwiftData

// MARK: - MergedPRsTodayView

/// Displays a list of pull requests merged today, grouped by repository.
struct MergedPRsTodayView: View {

    // MARK: - Properties

    /// The authentication service, providing token access for API calls.
    @Environment(AuthenticationService.self) private var authService

    /// All repositories the user has saved, sorted alphabetically by display name.
    @Query(sort: \SavedRepository.displayName) private var savedRepositories: [SavedRepository]

    /// Whether a data fetch is currently in progress.
    @State private var isLoading = false

    /// The most recent error encountered during data loading, or `nil` if none.
    @State private var error: GitHubError?

    /// Merged PRs keyed by the `owner/name` repository identifier.
    @State private var prsByRepo: [String: [MergedPR]] = [:]

    /// All merged PRs across every repository, as a flat list.
    private var allPRs: [MergedPR] { prsByRepo.values.flatMap { $0 } }

    /// The start of today in the device's local timezone.
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// A formatted long-style date string for today, used as the report subtitle.
    private var dateSubtitle: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .none
        return fmt.string(from: today)
    }

    /// A lookup map from lowercased `owner/name` key to the saved repository's display name.
    private var displayNameByRepo: [String: String] {
        Dictionary(uniqueKeysWithValues: savedRepositories.map { ("\($0.owner)/\($0.name)".lowercased(), $0.displayName) })
    }

    /// Repository sections sorted alphabetically, each containing their PRs sorted by merge time.
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
        .navigationSubtitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Private

    /// Fetches today's merged PRs for all saved repositories and updates the view state.
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
            prsByRepo = try await service.fetchMergedPRs(for: repos, on: today)
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }
}

// MARK: - RepoMergedPRsListView

/// Displays a scrollable list of merged pull requests for a single repository.
private struct RepoMergedPRsListView: View {

    // MARK: - Properties

    /// The display name of the repository shown in the navigation title.
    let repoName: String

    /// The merged pull requests to display.
    let prs: [MergedPR]

    /// The environment action used to open a pull request URL in the default browser.
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
