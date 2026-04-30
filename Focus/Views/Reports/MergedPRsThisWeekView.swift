import SwiftUI
import SwiftData

// MARK: - MergedPRsThisWeekView

/// Displays a list of pull requests merged during the current week, grouped by repository.
struct MergedPRsThisWeekView: View {

    // MARK: - Properties

    /// The authentication service, used to obtain a token provider for API requests.
    @Environment(AuthenticationService.self) private var authService

    /// All repositories the user has saved, sorted alphabetically by display name.
    @Query(sort: \SavedRepository.displayName) private var savedRepositories: [SavedRepository]

    /// Whether a data fetch is currently in progress.
    @State private var isLoading = false

    /// The number of repositories whose results have been received during the current fetch.
    @State private var loadedRepoCount = 0

    /// The total number of repositories being fetched in the current load.
    @State private var totalRepoCount = 0

    /// The last error returned by the data fetch, or `nil` if the last fetch succeeded.
    @State private var error: GitHubError?

    /// Merged PRs indexed by the lowercased `owner/name` repository key.
    @State private var prsByRepo: [String: [MergedPR]] = [:]

    /// All merged PRs across every repository, unsorted.
    private var allPRs: [MergedPR] { prsByRepo.values.flatMap { $0 } }

    /// A local-timezone Gregorian calendar with Monday as the first weekday.
    private var localCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        return cal
    }

    /// The start of the current ISO week in the device's local timezone (Monday at midnight local).
    private var weekStart: Date {
        localCalendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date!
    }

    /// The start of today in the device's local timezone.
    private var today: Date {
        localCalendar.startOfDay(for: Date())
    }

    /// A formatted date range string spanning from the week start through today (e.g. "Apr 7 – 13, 2026").
    private var dateSubtitle: String {
        let fmt = DateFormatter()
        let startComponents = localCalendar.dateComponents([.month, .day], from: weekStart)
        let endComponents = localCalendar.dateComponents([.year, .month, .day], from: today)

        fmt.dateFormat = "MMM d"
        let startStr = fmt.string(from: weekStart)

        if startComponents.month == endComponents.month {
            fmt.dateFormat = "d, yyyy"
        } else {
            fmt.dateFormat = "MMM d, yyyy"
        }
        let endStr = fmt.string(from: today)

        return "\(startStr) – \(endStr)"
    }

    /// A lookup from lowercased `owner/name` key to the repository's user-facing display name.
    private var displayNameByRepo: [String: String] {
        Dictionary(uniqueKeysWithValues: savedRepositories.map { ("\($0.owner)/\($0.name)".lowercased(), $0.displayName) })
    }

    /// Repository sections sorted alphabetically by display name, with each section's PRs sorted by merge date ascending.
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
                VStack(spacing: 12) {
                    ProgressView(value: Double(loadedRepoCount), total: Double(max(totalRepoCount, 1)))
                        .frame(maxWidth: 240)
                        .animation(.easeInOut(duration: 0.25), value: loadedRepoCount)
                    Text("\(loadedRepoCount) of \(totalRepoCount) repos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
        .navigationSubtitle("This Week")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Private

    /// Fetches merged PRs for all saved repositories within the current week and updates `prsByRepo`.
    ///
    /// Queries each repository concurrently for the full week-to-date range, keeping individual
    /// search queries simple and avoiding GitHub search API timeouts (502s).
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
            let start = weekStart
            let end = today

            totalRepoCount = repos.count
            loadedRepoCount = 0
            var merged: [String: [MergedPR]] = [:]

            try await withThrowingTaskGroup(of: [String: [MergedPR]].self) { group in
                for repo in repos {
                    group.addTask {
                        try await service.fetchMergedPRs(for: [repo], from: start, to: end)
                    }
                }
                for try await repoResult in group {
                    for (repo, prs) in repoResult {
                        merged[repo, default: []].append(contentsOf: prs)
                    }
                    loadedRepoCount += 1
                }
            }

            prsByRepo = merged
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }
}

// MARK: - RepoMergedPRsListView

/// Displays a list of merged pull requests for a single repository, each linking to its GitHub URL.
private struct RepoMergedPRsListView: View {

    // MARK: - Properties

    /// The display name of the repository shown in the navigation title.
    let repoName: String

    /// The merged pull requests to display, in the order provided by the caller.
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
