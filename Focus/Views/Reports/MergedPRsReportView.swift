import SwiftUI
import SwiftData

// MARK: - MergedPRPeriod

/// The time window shown in the merged PRs report.
enum MergedPRPeriod: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
}

// MARK: - MergedPRsReportView

/// Displays merged pull requests across all saved repositories for a selected time period.
///
/// Period data is cached in memory after the first fetch; switching to a previously loaded
/// period renders instantly. Pulling to refresh clears and reloads the current period only.
struct MergedPRsReportView: View {

    // MARK: - Properties

    /// The authentication service used to obtain a token for API requests.
    @Environment(AuthenticationService.self) private var authService

    /// All saved repositories, sorted alphabetically by display name.
    @Query(sort: \SavedRepository.displayName) private var savedRepositories: [SavedRepository]

    /// The period currently shown in the report.
    @State private var selectedPeriod: MergedPRPeriod = .today

    /// Fetched PR data keyed by period, populated lazily on first view of each period.
    @State private var cache: [MergedPRPeriod: [String: [MergedPR]]] = [:]

    /// The set of periods currently being fetched from the API.
    @State private var loadingPeriods: Set<MergedPRPeriod> = []

    /// Progress counters for the concurrent per-repo fetches used by week periods.
    @State private var loadedRepoCount = 0
    @State private var totalRepoCount = 0

    /// The last error from the most recent fetch of the currently selected period.
    @State private var error: GitHubError?

    /// PR data for the currently selected period.
    private var currentPRsByRepo: [String: [MergedPR]] { cache[selectedPeriod] ?? [:] }

    /// All PRs across every repository for the selected period.
    private var allPRs: [MergedPR] { currentPRsByRepo.values.flatMap { $0 } }

    /// Whether the selected period is currently being fetched.
    private var isLoading: Bool { loadingPeriods.contains(selectedPeriod) }

    /// Lookup from lowercased `owner/name` key to the repository's display name.
    private var displayNameByRepo: [String: String] {
        savedRepositories.reduce(into: [String: String]()) {
            $0["\($1.owner)/\($1.name)".lowercased()] = $1.displayName
        }
    }

    /// Repository sections sorted alphabetically, each section's PRs sorted by merge time.
    private var repoSections: [(repoName: String, prs: [MergedPR])] {
        let lookup = displayNameByRepo
        return currentPRsByRepo
            .map { (repoName: lookup[$0.key.lowercased()] ?? $0.key, prs: $0.value.sorted { $0.mergedAt < $1.mergedAt }) }
            .sorted { $0.repoName < $1.repoName }
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Group {
            if isLoading && allPRs.isEmpty {
                loadingView
            } else if let error, allPRs.isEmpty {
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
                            Text(dateSubtitle(for: selectedPeriod))
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
                .refreshable {
                    cache[selectedPeriod] = nil
                    error = nil
                    await loadData(for: selectedPeriod)
                }
            }
        }
        .navigationTitle("Merged PRs")
        .navigationSubtitle(selectedPeriod.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(MergedPRPeriod.allCases, id: \.self) { period in
                        Button {
                            selectedPeriod = period
                        } label: {
                            Label(period.rawValue, systemImage: selectedPeriod == period ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(selectedPeriod.rawValue, systemImage: "calendar")
                }
            }
        }
        .task {
            if cache[selectedPeriod] == nil {
                await loadData(for: selectedPeriod)
            }
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            guard cache[newPeriod] == nil else { return }
            Task { await loadData(for: newPeriod) }
        }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        switch selectedPeriod {
        case .today, .yesterday:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .thisWeek, .lastWeek:
            VStack(spacing: 12) {
                ProgressView(value: Double(loadedRepoCount), total: Double(max(totalRepoCount, 1)))
                    .frame(maxWidth: 240)
                    .animation(.easeInOut(duration: 0.25), value: loadedRepoCount)
                Text("\(loadedRepoCount) of \(totalRepoCount) repos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Date Subtitles

    private func dateSubtitle(for period: MergedPRPeriod) -> String {
        switch period {
        case .today:
            return longDate(startOfToday())
        case .yesterday:
            return longDate(startOfYesterday())
        case .thisWeek:
            return weekRange(from: thisWeekStart(), to: startOfToday(), using: isoCalendar())
        case .lastWeek:
            let cal = sundayCalendar()
            return weekRange(from: lastWeekStart(cal), to: lastWeekEnd(cal), using: cal)
        }
    }

    // MARK: - Date Helpers

    private func isoCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }

    private func sundayCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        return cal
    }

    private func startOfToday() -> Date { Calendar.current.startOfDay(for: Date()) }

    private func startOfYesterday() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: startOfToday())!
    }

    private func thisWeekStart() -> Date {
        isoCalendar().dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date!
    }

    private func lastWeekStart(_ cal: Calendar) -> Date {
        let thisWeek = cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date!
        return cal.date(byAdding: .weekOfYear, value: -1, to: thisWeek)!
    }

    private func lastWeekEnd(_ cal: Calendar) -> Date {
        let thisWeek = cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date!
        return cal.date(byAdding: .day, value: -1, to: thisWeek)!
    }

    private func longDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    private func weekRange(from start: Date, to end: Date, using cal: Calendar) -> String {
        let fmt = DateFormatter()
        let startMonth = cal.component(.month, from: start)
        let endMonth = cal.component(.month, from: end)

        fmt.dateFormat = "MMM d"
        let startStr = fmt.string(from: start)
        fmt.dateFormat = startMonth == endMonth ? "d, yyyy" : "MMM d, yyyy"
        return "\(startStr) – \(fmt.string(from: end))"
    }

    // MARK: - Data Loading

    @MainActor
    private func loadData(for period: MergedPRPeriod) async {
        guard !loadingPeriods.contains(period) else { return }
        loadingPeriods.insert(period)
        if period == selectedPeriod { error = nil }

        let service = MergedPRReportService(
            graphQL: GraphQLClient(tokenProvider: authService.tokenProvider)
        )
        let repos = savedRepositories.map { (owner: $0.owner, name: $0.name) }

        do {
            let result: [String: [MergedPR]]

            switch period {
            case .today:
                result = try await service.fetchMergedPRs(for: repos, on: startOfToday())
            case .yesterday:
                result = try await service.fetchMergedPRs(for: repos, on: startOfYesterday())
            case .thisWeek:
                result = try await fetchConcurrently(
                    service: service, repos: repos,
                    from: thisWeekStart(), to: startOfToday(),
                    trackingProgressFor: period
                )
            case .lastWeek:
                let cal = sundayCalendar()
                result = try await fetchConcurrently(
                    service: service, repos: repos,
                    from: lastWeekStart(cal), to: lastWeekEnd(cal),
                    trackingProgressFor: period
                )
            }

            cache[period] = result
        } catch let ghError as GitHubError {
            if period == selectedPeriod { self.error = ghError }
        } catch {
            if period == selectedPeriod { self.error = .networkError(underlying: error) }
        }

        loadingPeriods.remove(period)
    }

    /// Fetches PRs for each repository concurrently, updating the progress counters when
    /// `period` matches the currently selected period.
    @MainActor
    private func fetchConcurrently(
        service: MergedPRReportService,
        repos: [(owner: String, name: String)],
        from start: Date,
        to end: Date,
        trackingProgressFor period: MergedPRPeriod
    ) async throws -> [String: [MergedPR]] {
        if period == selectedPeriod {
            totalRepoCount = repos.count
            loadedRepoCount = 0
        }

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
                if period == selectedPeriod { loadedRepoCount += 1 }
            }
        }

        return merged
    }
}

// MARK: - RepoMergedPRsListView

/// Displays a list of merged pull requests for a single repository, each linking to GitHub.
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
