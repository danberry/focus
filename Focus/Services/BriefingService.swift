import Foundation
import SwiftData

// MARK: - BriefingService

/// Assembles the weekly Focus Briefing by combining fresh GraphQL PR counts
/// with the local SwiftData graph.
///
/// `BriefingService` covers the previous calendar week (Monday 00:00 through
/// Sunday 23:59 in the user's locale). Merged PR counts are fetched fresh
/// from the GitHub GraphQL Search API; security alerts and member contribution
/// data are read from SwiftData (populated by the existing sync pipeline).
///
/// All network calls go through the injected ``GraphQLClient``. Failures at
/// any stage collapse to ``Briefing/placeholder`` so the view layer can always
/// render.
struct BriefingService: Sendable {

    // MARK: - Properties

    /// The GraphQL client used to execute merged PR count queries.
    private let graphQL: GraphQLClient

    /// The REST client used to fetch dismissed Dependabot alerts for Tier 3 rules.
    ///
    /// `nil` in test environments and before the token is available; Tier 3 rules
    /// no-op gracefully when `currentWeekTotals` is not populated.
    private let rest: RESTClient?

    // MARK: - Init

    /// Creates a briefing service backed by the given clients.
    ///
    /// - Parameters:
    ///   - graphQL: The client used to execute search queries against the GitHub GraphQL API.
    ///   - rest: Optional REST client used to fetch dismissed Dependabot alert counts.
    ///           Pass `nil` (the default) to skip the closure-velocity fetch.
    init(graphQL: GraphQLClient, rest: RESTClient? = nil) {
        self.graphQL = graphQL
        self.rest = rest
    }

    // MARK: - Generation

    /// Builds a ``Briefing`` for the previous calendar week, optionally filtered by scope.
    ///
    /// The returned briefing combines fresh merged PR counts (fetched in parallel) with
    /// security alerts and member contributions read from the supplied SwiftData context.
    /// When `scope` is not ``BriefingScope/all``, the fetched repositories and members are
    /// filtered to the matching team, department, or organization before any aggregation.
    ///
    /// If week computation or repository fetching fails, returns ``Briefing/placeholder``.
    ///
    /// - Parameters:
    ///   - scope: The filter that restricts the data graph read from `context`; defaults to ``BriefingScope/all``.
    ///   - context: The SwiftData model context used to read the local graph.
    /// - Returns: An assembled ``Briefing`` for the previous week.
    @MainActor
    func generate(scope: BriefingScope = .all, in context: ModelContext) async -> Briefing {
        guard let weekInterval = previousWeekInterval() else {
            return Briefing.placeholder
        }

        let weekRange = formatWeekRange(weekInterval)
        let ghRange = githubDateRange(for: weekInterval)

        let repositories: [SavedRepository]
        do {
            repositories = try context.fetch(FetchDescriptor<SavedRepository>())
        } catch {
            return Briefing.placeholder
        }

        let members = (try? context.fetch(FetchDescriptor<Member>())) ?? []

        let scopedRepos = filter(repositories: repositories, by: scope)
        let scopedMembers = filter(members: members, by: scope)

        // Snapshot Sendable (owner, repo) pairs for the non-isolated fetch fan-out.
        let repoKeys: [(owner: String, name: String)] = scopedRepos.map { ($0.owner, $0.name) }

        var cal = Calendar.current
        cal.firstWeekday = 1
        let priorWeekStart = weekInterval.start.addingTimeInterval(-1)
        let priorGhRange = cal.dateInterval(of: .weekOfYear, for: priorWeekStart)
            .map { githubDateRange(for: $0) } ?? ""

        let priorWeekInterval = cal.dateInterval(of: .weekOfYear, for: priorWeekStart) ?? weekInterval
        async let prCountsFetch = fetchAllPRCounts(repoKeys: repoKeys, range: ghRange)
        async let metricsFetch = fetchMergedPRMetrics(repoKeys: repoKeys, interval: weekInterval)
        async let releasesFetch = fetchReleaseCount(repoKeys: repoKeys, since: weekInterval.start)
        async let priorReleasesFetch = fetchReleaseCount(repoKeys: repoKeys, since: priorWeekStart, until: weekInterval.start)
        async let priorPRCountsFetch = fetchAllPRCounts(repoKeys: repoKeys, range: priorGhRange)
        async let priorMetricsFetch = fetchMergedPRMetrics(repoKeys: repoKeys, interval: priorWeekInterval)
        async let ciPassFetch = fetchCIPassRate(repoKeys: repoKeys, range: ghRange)
        async let priorCIPassFetch = fetchCIPassRate(repoKeys: repoKeys, range: priorGhRange)
        async let openedPRCountsFetch = fetchAllOpenedPRCounts(repoKeys: repoKeys, range: ghRange)
        async let priorOpenedPRCountsFetch = fetchAllOpenedPRCounts(repoKeys: repoKeys, range: priorGhRange)
        let (prCounts, metrics, releaseCount, priorReleaseCount, priorPRCounts, priorMetrics, ciPassPct, priorCIPassPct, openedPRCounts, priorOpenedPRCounts) = await (prCountsFetch, metricsFetch, releasesFetch, priorReleasesFetch, priorPRCountsFetch, priorMetricsFetch, ciPassFetch, priorCIPassFetch, openedPRCountsFetch, priorOpenedPRCountsFetch)
        let unreviewedCount = metrics.unreviewedCount
        let totalPRCount = metrics.totalPRCount
        let priorUnreviewedCount = priorMetrics.unreviewedCount
        let priorTotalPRCount = priorMetrics.totalPRCount

        let criticalDescriptor = FetchDescriptor<DependabotAlert>(
            predicate: #Predicate { $0.severity == "critical" }
        )
        let criticalAlerts = (try? context.fetch(criticalDescriptor)) ?? []

        // Fetch the full alert sets once; they're reused for the sparkline,
        // the security insight generator, and the per-repo rollups.
        let allDependabotAlerts = (try? context.fetch(FetchDescriptor<DependabotAlert>())) ?? []
        let allCodeScanningAlerts = (try? context.fetch(FetchDescriptor<CodeScanningAlert>())) ?? []
        let allSecretAlerts = (try? context.fetch(FetchDescriptor<SecretScanningAlert>())) ?? []
        let allAlertDates = allDependabotAlerts.map(\.createdAt)
            + allCodeScanningAlerts.map(\.createdAt)
            + allSecretAlerts.map(\.createdAt)

        // Tier 2: persist snapshot and load trend history.
        let (baseCurrentWeekTotals, priorWeekTotals, weekHistory) = persistSecuritySnapshot(
            weekInterval: weekInterval,
            repositories: scopedRepos,
            criticalAlerts: criticalAlerts,
            allDependabotAlerts: allDependabotAlerts,
            context: context
        )

        // Tier 3: fetch dismissed Dependabot alert counts per repo and merge into currentWeekTotals.
        let repoClosedCounts: [String: Int]
        if let restClient = rest {
            let secService = SecurityService(rest: restClient)
            repoClosedCounts = await fetchDismissedCounts(
                repoKeys: repoKeys,
                displayNames: scopedRepos.map(\.displayName),
                securityService: secService,
                since: weekInterval.start,
                until: weekInterval.end
            )
        } else {
            repoClosedCounts = [:]
        }
        let totalClosed = repoClosedCounts.values.reduce(0, +)
        // Rebuild currentWeekTotals with actual closed counts; repoClosedCounts is always
        // empty in the snapshot since it is fetched live each session.
        let currentWeekTotals: SecurityWeekTotals? = baseCurrentWeekTotals.map { base in
            SecurityWeekTotals(
                weekStart: base.weekStart,
                totalOpen: base.totalOpen,
                totalCritical: base.totalCritical,
                opened: base.opened,
                closed: totalClosed,
                repoCriticalCounts: base.repoCriticalCounts,
                repoClosedCounts: repoClosedCounts
            )
        }

        return assemble(
            weekInterval: weekInterval,
            weekRange: weekRange,
            repositories: scopedRepos,
            prCounts: prCounts,
            priorWeekPRTotal: priorPRCounts.values.reduce(0, +),
            shippingDailyCounts: metrics.dailyCounts,
            medianMergeHours: metrics.medianHours,
            dailyCycleTimeMedians: metrics.dailyCycleTimeMedians,
            priorMedianMergeHours: priorMetrics.medianHours,
            medianFirstReviewHours: metrics.medianFirstReviewHours,
            dailyFirstReviewMedians: metrics.dailyFirstReviewMedians,
            priorMedianFirstReviewHours: priorMetrics.medianFirstReviewHours,
            hotfixCount: metrics.hotfixCount,
            totalMerged: metrics.totalMerged,
            priorHotfixCount: priorMetrics.hotfixCount,
            priorTotalMerged: priorMetrics.totalMerged,
            medianPRSize: metrics.medianPRSize,
            dailyPRSizeMedians: metrics.dailyPRSizeMedians,
            priorMedianPRSize: priorMetrics.medianPRSize,
            ciPassPct: ciPassPct,
            priorCIPassPct: priorCIPassPct,
            releaseCount: releaseCount,
            priorReleaseCount: priorReleaseCount,
            openedPRTotal: openedPRCounts.values.reduce(0, +),
            priorOpenedPRTotal: priorOpenedPRCounts.values.reduce(0, +),
            unreviewedCount: unreviewedCount,
            totalPRCount: totalPRCount,
            priorUnreviewedCount: priorUnreviewedCount,
            priorTotalPRCount: priorTotalPRCount,
            criticalAlerts: criticalAlerts,
            allDependabotAlerts: allDependabotAlerts,
            allCodeScanningAlerts: allCodeScanningAlerts,
            allSecretAlerts: allSecretAlerts,
            allAlertDates: allAlertDates,
            members: scopedMembers,
            currentWeekTotals: currentWeekTotals,
            priorWeekTotals: priorWeekTotals,
            weekHistory: weekHistory
        )
    }

    // MARK: - Security Snapshot Persistence

    /// Writes or updates the ``SecurityWeeklySnapshot`` for `weekInterval`, then returns
    /// the trend data needed by Tier 2 insight rules.
    ///
    /// The returned `weekHistory` array contains up to 8 snapshots sorted oldest-first.
    /// `currentWeekTotals` and `priorWeekTotals` are derived from that history.
    ///
    /// - Parameters:
    ///   - weekInterval: The week being briefed.
    ///   - repositories: Scoped saved repositories (used for totalOpen count).
    ///   - criticalAlerts: All `DependabotAlert` records at critical severity.
    ///   - allDependabotAlerts: All open `DependabotAlert` records (used for `opened` count).
    ///   - context: The SwiftData context to read and write snapshots.
    /// - Returns: A tuple of (currentWeekTotals, priorWeekTotals, weekHistory).
    @MainActor
    private func persistSecuritySnapshot(
        weekInterval: DateInterval,
        repositories: [SavedRepository],
        criticalAlerts: [DependabotAlert],
        allDependabotAlerts: [DependabotAlert],
        context: ModelContext
    ) -> (current: SecurityWeekTotals?, prior: SecurityWeekTotals?, history: [SecurityWeekTotals]) {
        let weekStart = weekInterval.start
        let totalOpen = repositories.reduce(0) { $0 + $1.totalSecurityAlerts }
        let totalCritical = criticalAlerts.count
        let opened = allDependabotAlerts.filter { weekInterval.contains($0.createdAt) }.count

        var repoCriticalCounts: [String: Int] = [:]
        for repo in repositories {
            let count = criticalAlerts.filter { $0.repository?.githubId == repo.githubId }.count
            if count > 0 {
                repoCriticalCounts[repo.displayName] = count
            }
        }

        // Upsert: update existing record for this week, or insert a new one.
        let nextWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
        let existing = try? context.fetch(FetchDescriptor<SecurityWeeklySnapshot>(
            predicate: #Predicate { $0.weekStart >= weekStart && $0.weekStart < nextWeekStart }
        ))
        if let snapshot = existing?.first {
            snapshot.totalOpen = totalOpen
            snapshot.totalCritical = totalCritical
            snapshot.opened = opened
            snapshot.repoCriticalCountsJSON = try? JSONEncoder().encode(repoCriticalCounts)
        } else {
            context.insert(SecurityWeeklySnapshot(
                weekStart: weekStart,
                totalOpen: totalOpen,
                totalCritical: totalCritical,
                opened: opened,
                repoCriticalCounts: repoCriticalCounts
            ))
        }
        try? context.save()

        // Fetch the 8 most recent snapshots, return oldest-first.
        var descriptor = FetchDescriptor<SecurityWeeklySnapshot>(
            sortBy: [SortDescriptor(\.weekStart, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        let snapshots = ((try? context.fetch(descriptor)) ?? []).reversed()

        func toTotals(_ s: SecurityWeeklySnapshot) -> SecurityWeekTotals {
            SecurityWeekTotals(
                weekStart: s.weekStart,
                totalOpen: s.totalOpen,
                totalCritical: s.totalCritical,
                opened: s.opened,
                closed: s.closed,
                repoCriticalCounts: s.repoCriticalCounts,
                repoClosedCounts: [:]
            )
        }

        let history = snapshots.map(toTotals)
        let current = history.last
        let prior = history.count >= 2 ? history[history.count - 2] : nil
        return (current, prior, history)
    }

    // MARK: - Scope Filtering

    /// Filters a flat list of saved repositories down to those matching the given scope.
    ///
    /// Team and department membership are resolved through the repository's `team` →
    /// `department` chain. The organization case uses the ``SavedRepository/organizationLogin``
    /// soft foreign key rather than a direct relationship.
    ///
    /// - Parameters:
    ///   - repositories: The full set of saved repositories fetched from SwiftData.
    ///   - scope: The scope to filter by. ``BriefingScope/all`` returns the input unchanged.
    /// - Returns: The subset of `repositories` that belong to the scope.
    @MainActor
    private func filter(repositories: [SavedRepository], by scope: BriefingScope) -> [SavedRepository] {
        switch scope {
        case .all:
            return repositories
        case .team(let team):
            return repositories.filter { $0.team?.persistentModelID == team.persistentModelID }
        case .department(let dept):
            return repositories.filter { $0.team?.department?.persistentModelID == dept.persistentModelID }
        case .organization(let org):
            return repositories.filter { $0.organizationLogin == org.login }
        }
    }

    /// Filters a flat list of members down to those matching the given scope.
    ///
    /// Members without a team never match a team, department, or organization scope.
    /// Department and organization membership are resolved by traversing the member's
    /// `team` → `department`/`organization` chain.
    ///
    /// - Parameters:
    ///   - members: The full set of members fetched from SwiftData.
    ///   - scope: The scope to filter by. ``BriefingScope/all`` returns the input unchanged.
    /// - Returns: The subset of `members` that belong to the scope.
    @MainActor
    private func filter(members: [Member], by scope: BriefingScope) -> [Member] {
        switch scope {
        case .all:
            return members
        case .team(let team):
            return members.filter { $0.team?.persistentModelID == team.persistentModelID }
        case .department(let dept):
            return members.filter { $0.team?.department?.persistentModelID == dept.persistentModelID }
        case .organization(let org):
            return members.filter { $0.team?.organization?.persistentModelID == org.persistentModelID }
        }
    }

    // MARK: - Week Computation

    /// Computes the previous calendar week's interval (Monday 00:00 → Sunday 23:59:59.999).
    ///
    /// The week boundary uses the user's current calendar with Monday (`firstWeekday = 2`)
    /// as the first day of the week.
    ///
    /// - Returns: The previous week's `DateInterval`, or `nil` if date arithmetic fails.
    func previousWeekInterval() -> DateInterval? {
        var cal = Calendar.current
        cal.firstWeekday = 1
        guard let lastWeekDate = cal.date(byAdding: .weekOfYear, value: -1, to: Date()) else {
            return nil
        }
        return cal.dateInterval(of: .weekOfYear, for: lastWeekDate)
    }

    /// Formats a week interval as a human-readable range string.
    ///
    /// When the start and end fall in the same month, the result is
    /// `"MMM d — d, yyyy"`; otherwise the full month is repeated, e.g.
    /// `"Apr 27 — May 3, 2026"`. The end date is rendered one second before
    /// `interval.end` so inclusive Sunday dates appear rather than the
    /// following Monday.
    ///
    /// - Parameter interval: The week interval to format.
    /// - Returns: A formatted range string suitable for display.
    func formatWeekRange(_ interval: DateInterval) -> String {
        let cal = Calendar.current
        let start = interval.start
        let endInclusive = interval.end.addingTimeInterval(-1)

        let startFmt = DateFormatter()
        startFmt.dateFormat = "MMM d"

        let endFmt = DateFormatter()
        let sameMonth = cal.component(.month, from: start) == cal.component(.month, from: endInclusive)
        endFmt.dateFormat = sameMonth ? "d, yyyy" : "MMM d, yyyy"

        return "\(startFmt.string(from: start)) — \(endFmt.string(from: endInclusive))"
    }

    /// Formats a week interval as a GitHub Search `merged:` range string.
    ///
    /// Returns a `"yyyy-MM-dd..yyyy-MM-dd"` string where the end date is one
    /// day before `interval.end` (since `interval.end` is exclusive and points
    /// at the following Monday).
    ///
    /// - Parameter interval: The week interval to convert.
    /// - Returns: A GitHub-compatible date-range string.
    func githubDateRange(for interval: DateInterval) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let endInclusive = interval.end.addingTimeInterval(-24 * 60 * 60)
        return "\(fmt.string(from: interval.start))..\(fmt.string(from: endInclusive))"
    }

    // MARK: - Dismissed Alert Fetch

    /// Fans out dismissed Dependabot alert count requests across all repositories in parallel.
    ///
    /// Returns a dictionary keyed by repository display name mapping to the count of
    /// alerts dismissed within `[since, until)`.
    func fetchDismissedCounts(
        repoKeys: [(owner: String, name: String)],
        displayNames: [String],
        securityService: SecurityService,
        since: Date,
        until: Date
    ) async -> [String: Int] {
        await withTaskGroup(of: (String, Int).self) { group in
            for (key, displayName) in zip(repoKeys, displayNames) {
                let owner = key.owner
                let name = key.name
                group.addTask {
                    let count = await securityService.fetchDismissedAlertCount(
                        owner: owner, repo: name, since: since, until: until
                    )
                    return (displayName, count)
                }
            }
            var result: [String: Int] = [:]
            for await (key, count) in group where count > 0 {
                result[key] = count
            }
            return result
        }
    }

    // MARK: - PR Fetch

    /// Fans out merged-PR-count requests across all repositories in parallel.
    ///
    /// - Parameters:
    ///   - repoKeys: The `(owner, name)` pairs to query.
    ///   - range: The GitHub `merged:` range string applied to each query.
    /// - Returns: A dictionary keyed by `"owner/name"` mapping to merged PR count.
    func fetchAllPRCounts(
        repoKeys: [(owner: String, name: String)],
        range: String
    ) async -> [String: Int] {
        await withTaskGroup(of: (String, Int).self) { group in
            for key in repoKeys {
                let owner = key.owner
                let name = key.name
                group.addTask {
                    let count = await self.fetchMergedPRCount(owner: owner, repo: name, range: range)
                    return ("\(owner)/\(name)", count)
                }
            }
            var result: [String: Int] = [:]
            for await (key, count) in group {
                result[key] = count
            }
            return result
        }
    }

    /// Fans out opened-PR-count requests across all repositories in parallel.
    ///
    /// Uses the `created:` qualifier instead of `merged:`, so the count reflects how many
    /// PRs were opened during the week regardless of whether they were merged.
    ///
    /// - Parameters:
    ///   - repoKeys: The `(owner, name)` pairs to query.
    ///   - range: The GitHub `created:` range string applied to each query.
    /// - Returns: A dictionary keyed by `"owner/name"` mapping to opened PR count.
    func fetchAllOpenedPRCounts(
        repoKeys: [(owner: String, name: String)],
        range: String
    ) async -> [String: Int] {
        await withTaskGroup(of: (String, Int).self) { group in
            for key in repoKeys {
                let owner = key.owner
                let name = key.name
                group.addTask {
                    let count = await self.fetchOpenedPRCount(owner: owner, repo: name, range: range)
                    return ("\(owner)/\(name)", count)
                }
            }
            var result: [String: Int] = [:]
            for await (key, count) in group {
                result[key] = count
            }
            return result
        }
    }

    /// Fetches the opened pull request count for a single repository and date range.
    ///
    /// Returns `0` on any network, decoding, or transport error.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login.
    ///   - repo: The repository name.
    ///   - range: The GitHub `created:` range string.
    /// - Returns: The opened PR count for the window, or `0` on failure.
    func fetchOpenedPRCount(owner: String, repo: String, range: String) async -> Int {
        let query = "repo:\(owner)/\(repo) is:pr created:\(range)"
        do {
            let response: WeeklyPRCountResponse = try await graphQL.execute(
                query: BriefingQueries.weeklyOpenedPRCount,
                variables: ["q": query],
                responseType: WeeklyPRCountResponse.self
            )
            return response.search.issueCount
        } catch {
            return 0
        }
    }

    /// Fetches the merged pull request count for a single repository and date range.
    ///
    /// Returns `0` on any network, decoding, or transport error.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login.
    ///   - repo: The repository name.
    ///   - range: The GitHub `merged:` range string.
    /// - Returns: The merged PR count for the window, or `0` on failure.
    func fetchMergedPRCount(owner: String, repo: String, range: String) async -> Int {
        let query = "repo:\(owner)/\(repo) is:pr is:merged merged:\(range)"
        do {
            let response: WeeklyPRCountResponse = try await graphQL.execute(
                query: BriefingQueries.weeklyMergedPRCount,
                variables: ["q": query],
                responseType: WeeklyPRCountResponse.self
            )
            return response.search.issueCount
        } catch {
            return 0
        }
    }

    /// Fetches merged PR data for the week and derives the median cycle time, per-day merged counts,
    /// PR size metrics, and daily cycle time medians (Monday = index 0 … Sunday = index 6).
    ///
    /// Returns `medianHours == nil` when there are no repos, no PRs, or on error.
    /// Returns `dailyCounts` and `dailyCycleTimeMedians` as seven zeros on error.
    private func fetchMergedPRMetrics(
        repoKeys: [(owner: String, name: String)],
        interval: DateInterval
    ) async -> (medianHours: Int?, dailyCounts: [Int], medianPRSize: Int?, dailyPRSizeMedians: [Int], dailyCycleTimeMedians: [Int], medianFirstReviewHours: Int?, dailyFirstReviewMedians: [Int], hotfixCount: Int, totalMerged: Int, unreviewedCount: Int, totalPRCount: Int) {
        let zeros7 = [Int](repeating: 0, count: 7)
        guard !repoKeys.isEmpty else { return (nil, zeros7, nil, zeros7, zeros7, nil, zeros7, 0, 0, 0, 0) }
        let service = MergedPRReportService(graphQL: graphQL)
        let endDate = interval.end.addingTimeInterval(-1)
        guard let prsByRepo = try? await service.fetchMergedPRs(for: repoKeys, from: interval.start, to: endDate) else {
            return (nil, zeros7, nil, zeros7, zeros7, nil, zeros7, 0, 0, 0, 0)
        }
        let medianHours = computeMedianMergeHours(from: prsByRepo)
        let dailyCounts = computeDailyCounts(from: prsByRepo, interval: interval)
        let medianPRSize = computeMedianPRSize(from: prsByRepo)
        let dailyPRSizeMedians = computeDailyPRSizeMedians(from: prsByRepo, interval: interval)
        let dailyCycleTimeMedians = computeDailyCycleTimeMedians(from: prsByRepo, interval: interval)
        let medianFirstReviewHours = computeMedianFirstReviewHours(from: prsByRepo)
        let dailyFirstReviewMedians = computeDailyFirstReviewMedians(from: prsByRepo, interval: interval)
        let hotfixCount = computeHotfixCount(from: prsByRepo)
        let totalMerged = prsByRepo.values.reduce(0) { $0 + $1.count }
        let (unreviewedCount, totalPRCount) = computeUnreviewedStats(from: prsByRepo)
        return (medianHours, dailyCounts, medianPRSize, dailyPRSizeMedians, dailyCycleTimeMedians, medianFirstReviewHours, dailyFirstReviewMedians, hotfixCount, totalMerged, unreviewedCount, totalPRCount)
    }

    private func computeUnreviewedStats(from prsByRepo: [String: [MergedPR]]) -> (unreviewed: Int, total: Int) {
        let all = prsByRepo.values.flatMap { $0 }
        let unreviewed = all.filter { $0.firstReviewAt == nil }.count
        return (unreviewed, all.count)
    }

    /// Computes the median open-to-merge cycle time in whole hours from a repo-keyed PR dictionary.
    private func computeMedianMergeHours(from prsByRepo: [String: [MergedPR]]) -> Int? {
        let cycleTimes: [Double] = prsByRepo.values.flatMap { $0 }.compactMap { pr in
            let hours = pr.mergedAt.timeIntervalSince(pr.createdAt) / 3600
            return hours >= 0 ? hours : nil
        }
        guard !cycleTimes.isEmpty else { return nil }
        let sorted = cycleTimes.sorted()
        let mid = sorted.count / 2
        let median = sorted.count % 2 == 0
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
        return Int(median.rounded())
    }

    /// Returns a 7-element array of median cycle-time hours per day (Mon=0…Sun=6).
    /// Cycle time is measured from PR creation to merge. Days with no merged PRs produce 0.
    private func computeDailyCycleTimeMedians(from prsByRepo: [String: [MergedPR]], interval: DateInterval) -> [Int] {
        var buckets: [[Double]] = Array(repeating: [], count: 7)
        let cal = Calendar.current
        let weekStart = cal.startOfDay(for: interval.start)
        for pr in prsByRepo.values.flatMap({ $0 }) {
            let hours = pr.mergedAt.timeIntervalSince(pr.createdAt) / 3600
            guard hours >= 0 else { continue }
            let dayIndex = cal.dateComponents([.day], from: weekStart, to: pr.mergedAt).day ?? -1
            if dayIndex >= 0 && dayIndex < 7 {
                buckets[dayIndex].append(hours)
            }
        }
        return buckets.map { hours in
            guard !hours.isEmpty else { return 0 }
            let sorted = hours.sorted()
            let mid = sorted.count / 2
            let median = sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
            return Int(median.rounded())
        }
    }

    /// Bins merged PRs by calendar day within the week, returning a 7-element array (Mon=0…Sun=6).
    private func computeDailyCounts(from prsByRepo: [String: [MergedPR]], interval: DateInterval) -> [Int] {
        var counts = [Int](repeating: 0, count: 7)
        let cal = Calendar.current
        let weekStart = cal.startOfDay(for: interval.start)
        for pr in prsByRepo.values.flatMap({ $0 }) {
            let dayIndex = cal.dateComponents([.day], from: weekStart, to: pr.mergedAt).day ?? -1
            if dayIndex >= 0 && dayIndex < 7 {
                counts[dayIndex] += 1
            }
        }
        return counts
    }

    /// Returns a 7-element array of median lines-changed per PR per day (Mon=0…Sun=6).
    /// Days with no merged PRs produce 0.
    private func computeDailyPRSizeMedians(from prsByRepo: [String: [MergedPR]], interval: DateInterval) -> [Int] {
        var buckets: [[Int]] = Array(repeating: [], count: 7)
        let cal = Calendar.current
        let weekStart = cal.startOfDay(for: interval.start)
        for pr in prsByRepo.values.flatMap({ $0 }) {
            let dayIndex = cal.dateComponents([.day], from: weekStart, to: pr.mergedAt).day ?? -1
            if dayIndex >= 0 && dayIndex < 7 {
                buckets[dayIndex].append(pr.linesChanged)
            }
        }
        return buckets.map { sizes in
            guard !sizes.isEmpty else { return 0 }
            let sorted = sizes.sorted()
            let mid = sorted.count / 2
            return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
        }
    }

    /// Computes the median time from PR open to first review in whole hours.
    ///
    /// Only PRs that received at least one review are included. Returns `nil` when no reviewed PRs exist.
    private func computeMedianFirstReviewHours(from prsByRepo: [String: [MergedPR]]) -> Int? {
        let times: [Double] = prsByRepo.values.flatMap { $0 }.compactMap { pr in
            guard let reviewAt = pr.firstReviewAt else { return nil }
            let hours = reviewAt.timeIntervalSince(pr.createdAt) / 3600
            return hours >= 0 ? hours : nil
        }
        guard !times.isEmpty else { return nil }
        let sorted = times.sorted()
        let mid = sorted.count / 2
        let median = sorted.count % 2 == 0
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
        return Int(median.rounded())
    }

    /// Returns a 7-element array of median time-to-first-review hours per day (Mon=0…Sun=6).
    /// Bucketed by the PR's merge date. Days with no reviewed PRs produce 0.
    private func computeDailyFirstReviewMedians(from prsByRepo: [String: [MergedPR]], interval: DateInterval) -> [Int] {
        var buckets: [[Double]] = Array(repeating: [], count: 7)
        let cal = Calendar.current
        let weekStart = cal.startOfDay(for: interval.start)
        for pr in prsByRepo.values.flatMap({ $0 }) {
            guard let reviewAt = pr.firstReviewAt else { continue }
            let hours = reviewAt.timeIntervalSince(pr.createdAt) / 3600
            guard hours >= 0 else { continue }
            let dayIndex = cal.dateComponents([.day], from: weekStart, to: pr.mergedAt).day ?? -1
            if dayIndex >= 0 && dayIndex < 7 {
                buckets[dayIndex].append(hours)
            }
        }
        return buckets.map { times in
            guard !times.isEmpty else { return 0 }
            let sorted = times.sorted()
            let mid = sorted.count / 2
            let median = sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
            return Int(median.rounded())
        }
    }

    /// Returns the count of merged PRs whose title matches a hotfix naming convention.
    ///
    /// Matches (case-insensitive): titles prefixed with `"hotfix:"`, `"[hotfix]"`, or `"hotfix/"`.
    private func computeHotfixCount(from prsByRepo: [String: [MergedPR]]) -> Int {
        prsByRepo.values.flatMap { $0 }.filter { pr in
            let lower = pr.title.lowercased()
            return lower.hasPrefix("hotfix:") || lower.hasPrefix("[hotfix]") || lower.hasPrefix("hotfix/")
        }.count
    }

    /// Computes the overall median lines-changed per PR for the week.
    private func computeMedianPRSize(from prsByRepo: [String: [MergedPR]]) -> Int? {
        let sizes: [Int] = prsByRepo.values.flatMap { $0 }.map { $0.linesChanged }
        guard !sizes.isEmpty else { return nil }
        let sorted = sizes.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    // MARK: - Release Fetch

    /// Fans out release-count requests across all repositories in parallel and sums the results.
    ///
    /// - Parameters:
    ///   - repoKeys: The `(owner, name)` pairs to query.
    ///   - since: Only releases published on or after this date are counted.
    /// - Returns: Total release count across all repos, or `nil` if there are no repos.
    func fetchReleaseCount(
        repoKeys: [(owner: String, name: String)],
        since: Date,
        until: Date? = nil
    ) async -> Int? {
        guard !repoKeys.isEmpty else { return nil }
        return await withTaskGroup(of: Int.self) { group in
            for key in repoKeys {
                let owner = key.owner
                let name = key.name
                group.addTask {
                    await self.fetchRepoReleaseCount(owner: owner, name: name, since: since, until: until)
                }
            }
            var total = 0
            for await count in group {
                total += count
            }
            return total
        }
    }

    /// Fetches the release count for a single repository published on or after `since`.
    ///
    /// Drafts are excluded because their `publishedAt` is null. Returns `0` on any error.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login.
    ///   - name: The repository name.
    ///   - since: Releases published before this date are ignored.
    /// - Returns: The number of qualifying releases, or `0` on failure.
    func fetchRepoReleaseCount(owner: String, name: String, since: Date, until: Date? = nil) async -> Int {
        do {
            let response: WeeklyReleasesResponse = try await graphQL.execute(
                query: BriefingQueries.recentReleases,
                variables: ["owner": owner, "name": name],
                responseType: WeeklyReleasesResponse.self
            )
            return response.repository?.releases.nodes
                .compactMap(\.publishedAt)
                .filter { date in date >= since && until.map { date < $0 } ?? true }
                .count ?? 0
        } catch {
            return 0
        }
    }

    // MARK: - CI Pass Rate Fetch

    /// Fans out CI pass rate requests across all repositories and returns an overall percentage.
    ///
    /// PRs whose head commit has no check rollup are excluded so they don't skew the rate.
    /// Returns `nil` when there are no repos or no PRs with checks across any repo.
    ///
    /// - Parameters:
    ///   - repoKeys: The `(owner, name)` pairs to query.
    ///   - range: The GitHub `merged:` range string applied to each query.
    /// - Returns: Percentage (0–100) of passing PRs, or `nil` if no PRs had checks.
    func fetchCIPassRate(
        repoKeys: [(owner: String, name: String)],
        range: String
    ) async -> Int? {
        guard !repoKeys.isEmpty else { return nil }
        var totalWithChecks = 0
        var totalPassed = 0
        await withTaskGroup(of: (withChecks: Int, passed: Int).self) { group in
            for key in repoKeys {
                let owner = key.owner
                let name = key.name
                group.addTask {
                    await self.fetchRepoCIPassRate(owner: owner, name: name, range: range)
                }
            }
            for await result in group {
                totalWithChecks += result.withChecks
                totalPassed += result.passed
            }
        }
        guard totalWithChecks > 0 else { return nil }
        return Int((Double(totalPassed) / Double(totalWithChecks) * 100).rounded())
    }

    /// Fetches CI pass/fail counts for a single repository by paginating through merged PRs.
    ///
    /// Only PRs whose head commit has a non-nil `statusCheckRollup` are counted.
    /// `"SUCCESS"` conclusions are counted as passed; all other concluded states are failed.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login.
    ///   - name: The repository name.
    ///   - range: The GitHub `merged:` range string.
    /// - Returns: A tuple of `(withChecks, passed)` counts.
    private func fetchRepoCIPassRate(owner: String, name: String, range: String) async -> (withChecks: Int, passed: Int) {
        let searchQuery = "repo:\(owner)/\(name) is:pr is:merged merged:\(range)"
        var withChecks = 0
        var passed = 0
        var cursor: String? = nil
        repeat {
            var variables: [String: any Sendable] = ["q": searchQuery]
            if let after = cursor { variables["after"] = after }
            guard let response = try? await graphQL.execute(
                query: BriefingQueries.ciPassRate,
                variables: variables,
                responseType: CIPassRateResponse.self
            ) else { break }
            for node in response.search.nodes {
                guard let rollup = node.commits?.nodes.first?.commit.statusCheckRollup else { continue }
                withChecks += 1
                if rollup.state == "SUCCESS" { passed += 1 }
            }
            if response.search.pageInfo.hasNextPage {
                cursor = response.search.pageInfo.endCursor
            } else {
                break
            }
        } while true
        return (withChecks, passed)
    }

    // MARK: - Assembly

    /// Builds a ``Briefing`` from pre-collected SwiftData entities and API counts.
    ///
    /// Performs all aggregation, ranking, and verdict-template construction on the
    /// main actor because the inputs include `@Model` objects whose property
    /// accesses must be main-actor isolated.
    ///
    /// - Parameters:
    ///   - weekInterval: The week interval covered by the briefing.
    ///   - weekRange: The pre-formatted human-readable range string.
    ///   - repositories: All saved repositories.
    ///   - prCounts: Merged PR counts keyed by `"owner/name"`.
    ///   - criticalAlerts: All `DependabotAlert` records at `"critical"` severity.
    ///   - members: All `Member` records.
    /// - Returns: The fully assembled ``Briefing``.
    @MainActor
    private func assemble(
        weekInterval: DateInterval,
        weekRange: String,
        repositories: [SavedRepository],
        prCounts: [String: Int],
        priorWeekPRTotal: Int,
        shippingDailyCounts: [Int],
        medianMergeHours: Int?,
        dailyCycleTimeMedians: [Int],
        priorMedianMergeHours: Int?,
        medianFirstReviewHours: Int?,
        dailyFirstReviewMedians: [Int],
        priorMedianFirstReviewHours: Int?,
        hotfixCount: Int,
        totalMerged: Int,
        priorHotfixCount: Int,
        priorTotalMerged: Int,
        medianPRSize: Int?,
        dailyPRSizeMedians: [Int],
        priorMedianPRSize: Int?,
        ciPassPct: Int?,
        priorCIPassPct: Int?,
        releaseCount: Int?,
        priorReleaseCount: Int?,
        openedPRTotal: Int,
        priorOpenedPRTotal: Int,
        unreviewedCount: Int,
        totalPRCount: Int,
        priorUnreviewedCount: Int,
        priorTotalPRCount: Int,
        criticalAlerts: [DependabotAlert],
        allDependabotAlerts: [DependabotAlert],
        allCodeScanningAlerts: [CodeScanningAlert],
        allSecretAlerts: [SecretScanningAlert],
        allAlertDates: [Date],
        members: [Member],
        currentWeekTotals: SecurityWeekTotals?,
        priorWeekTotals: SecurityWeekTotals?,
        weekHistory: [SecurityWeekTotals]
    ) -> Briefing {
        let volume = Calendar.current.component(.weekOfYear, from: weekInterval.start)

        // MARK: Shipping
        let shippingTotal = prCounts.values.reduce(0, +)

        // MARK: Time to First Review
        let timeToFirstReview: BriefingKPITimeToFirstReview? = medianFirstReviewHours.map {
            BriefingKPITimeToFirstReview(value: $0, dailyMedians: dailyFirstReviewMedians, priorWeekValue: priorMedianFirstReviewHours)
        }

        // MARK: Unreviewed Merge Rate
        let unreviewedMergeRate: BriefingKPIUnreviewedMergeRate? = totalPRCount > 0 ? {
            let pct = Int((Double(unreviewedCount) / Double(totalPRCount) * 100).rounded())
            let priorPct: Int? = priorTotalPRCount > 0
                ? Int((Double(priorUnreviewedCount) / Double(priorTotalPRCount) * 100).rounded())
                : nil
            return BriefingKPIUnreviewedMergeRate(value: pct, unreviewed: unreviewedCount, total: totalPRCount, priorWeekValue: priorPct)
        }() : nil

        // MARK: Merge Rate
        let mergeRate: BriefingKPIMergeRate? = openedPRTotal > 0 ? {
            let pct = Int((Double(shippingTotal) / Double(openedPRTotal) * 100).rounded())
            let priorPct: Int? = priorOpenedPRTotal > 0
                ? Int((Double(priorWeekPRTotal) / Double(priorOpenedPRTotal) * 100).rounded())
                : nil
            return BriefingKPIMergeRate(value: pct, merged: shippingTotal, opened: openedPRTotal, priorWeekValue: priorPct)
        }() : nil

        // MARK: Stale PRs
        let stalePRThresholdDays = 14
        let allOpenPRs = repositories.flatMap { $0.openPullRequests }
        let staleDate = weekInterval.end.addingTimeInterval(-Double(stalePRThresholdDays) * 86_400)
        let stalePRs = allOpenPRs.filter { $0.createdAt < staleDate }
        let priorStaleDate: Date = {
            var cal = Calendar.current
            cal.firstWeekday = 1
            if let priorEnd = cal.dateInterval(of: .weekOfYear, for: weekInterval.start.addingTimeInterval(-1))?.end {
                return priorEnd.addingTimeInterval(-Double(stalePRThresholdDays) * 86_400)
            }
            return staleDate
        }()
        let priorStalePRCount = allOpenPRs.filter { $0.createdAt < priorStaleDate }.count
        let oldestStalePRAgeDays: Int? = stalePRs
            .map { Calendar.current.dateComponents([.day], from: $0.createdAt, to: weekInterval.end).day ?? 0 }
            .max()
        let stalePRCount: BriefingKPIStalePRCount? = !allOpenPRs.isEmpty ? BriefingKPIStalePRCount(
            value: stalePRs.count,
            oldestAgeDays: oldestStalePRAgeDays,
            priorWeekValue: priorStalePRCount
        ) : nil

        // MARK: Hotfix Rate
        let hotfixRate: BriefingKPIHotfixRate? = totalMerged > 0 ? {
            let pct = Int((Double(hotfixCount) / Double(totalMerged) * 100).rounded())
            let priorPct: Int? = priorTotalMerged > 0
                ? Int((Double(priorHotfixCount) / Double(priorTotalMerged) * 100).rounded())
                : nil
            return BriefingKPIHotfixRate(value: pct, hotfixCount: hotfixCount, totalMerged: totalMerged, priorWeekValue: priorPct)
        }() : nil

        // MARK: Security
        let securityTotal = repositories.reduce(0) { $0 + $1.totalSecurityAlerts }
        let criticalCount = criticalAlerts.count

        let securityDailyOpenTotals = BriefingService.dailyOpenTotals(
            dates: allAlertDates,
            interval: weekInterval
        )
        // Open total at end of prior week = alerts created before the current week start.
        let securityPriorTotal = allAlertDates.filter { $0 < weekInterval.start }.count

        // MARK: Members — idle detection
        let weekEnd = weekInterval.end
        var idleMembers: [Member] = []
        var memberIdleLabels: [ObjectIdentifier: String] = [:]
        var totalTracked = 0

        for member in members {
            guard member.jobTitle?.discipline?.tracksGitHubActivity != false else { continue }
            totalTracked += 1

            let weekSum = member.dailyContributions
                .filter { weekInterval.contains($0.date) }
                .reduce(0) { $0 + $1.count }

            if weekSum == 0 {
                idleMembers.append(member)

                let lastActive = member.dailyContributions
                    .filter { $0.date < weekEnd && $0.count > 0 }
                    .map(\.date)
                    .max()

                let label: String
                if let lastActive {
                    let days = Calendar.current.dateComponents([.day], from: lastActive, to: weekEnd).day ?? 0
                    label = "\(days)d"
                } else {
                    label = "—"
                }
                memberIdleLabels[ObjectIdentifier(member)] = label
            }
        }

        var cal = Calendar.current
        cal.firstWeekday = 1
        let priorWeekInterval = cal.dateInterval(of: .weekOfYear, for: weekInterval.start.addingTimeInterval(-1))
        let priorIdleCount: Int = priorWeekInterval.map { prior in
            members.filter { member in
                guard member.jobTitle?.discipline?.tracksGitHubActivity != false else { return false }
                return member.dailyContributions
                    .filter { prior.contains($0.date) }
                    .reduce(0) { $0 + $1.count } == 0
            }.count
        } ?? 0
        let idleDelta = idleMembers.count - priorIdleCount

        // MARK: Shipped — repo ranking
        var repoRanking: [(repo: SavedRepository, count: Int)] = repositories.map { repo in
            (repo, prCounts["\(repo.owner)/\(repo.name)"] ?? 0)
        }
        repoRanking.sort { $0.count > $1.count }
        let repoCounts: [BriefingRepoCount] = repoRanking.enumerated().map { index, pair in
            BriefingRepoCount(name: pair.repo.displayName, count: pair.count, flag: index == 0)
        }

        let topRepoName = repoCounts.first?.name ?? "—"
        let topRepoCount = repoCounts.first?.count ?? 0
        let lowestRepo = repoRanking
            .filter { !$0.repo.isInMaintenance }
            .min { $0.count < $1.count }
            .map { BriefingRepoCount(name: $0.repo.displayName, count: $0.count, flag: false) }

        // MARK: Shipped — contributors (derived from Members' weekly contribution sums)
        var memberWeeklyCounts: [(member: Member, count: Int)] = []
        for member in members {
            let weekSum = member.dailyContributions
                .filter { weekInterval.contains($0.date) }
                .reduce(0) { $0 + $1.count }
            if weekSum > 0 {
                memberWeeklyCounts.append((member, weekSum))
            }
        }
        memberWeeklyCounts.sort { $0.count > $1.count }
        let contributors: [BriefingContributor] = memberWeeklyCounts.prefix(3).map { pair in
            BriefingContributor(
                initials: Self.initials(from: pair.member.name),
                name: pair.member.name,
                githubLogin: pair.member.githubLogin,
                count: pair.count
            )
        }

        let activeContributorCount = memberWeeklyCounts.count
        let priorActiveCount: Int? = priorWeekInterval.map { prior in
            members.filter { member in
                guard member.jobTitle?.discipline?.tracksGitHubActivity != false else { return false }
                return member.dailyContributions
                    .filter { prior.contains($0.date) }
                    .reduce(0) { $0 + $1.count } > 0
            }.count
        }

        // MARK: Blocked members
        let blockedMembers: [BriefingBlockedMember] = idleMembers.map { member in
            let label = memberIdleLabels[ObjectIdentifier(member)] ?? "—"
            let neverContributed = label == "—"
            let urgent = !neverContributed && label.hasSuffix("d") && (Int(label.dropLast()) ?? 0) >= 5
            let recommendation = neverContributed
                ? "No contributions on record. Verify their account is linked and active."
                : "No commits this week. Consider a check-in."
            return BriefingBlockedMember(
                initials: Self.initials(from: member.name),
                name: member.name,
                team: member.team?.name ?? "—",
                idleLabel: label,
                recommendation: recommendation,
                urgent: urgent,
                neverContributed: neverContributed,
                githubLogin: member.githubLogin
            )
        }

        // MARK: Attention items — §01 security, §02 idle, §03 shipping

        // Assemble the security input snapshot for the insight engine. Alert ages
        // are computed relative to the week-end so that "days open" is stable
        // regardless of when the briefing is rendered.
        let ageReference = weekInterval.end
        let cal2 = Calendar.current
        func days(between start: Date, and end: Date) -> Int {
            cal2.dateComponents([.day], from: start, to: end).day ?? 0
        }

        let dependabotSummaries: [DependabotAlertSummary] = allDependabotAlerts.map { alert in
            let repoName = alert.repository?.displayName ?? alert.repository?.name ?? "—"
            return DependabotAlertSummary(
                repoName: repoName,
                severity: alert.severity,
                ecosystem: alert.ecosystem,
                packageName: alert.packageName,
                ghsaId: alert.ghsaId,
                cvssScore: alert.cvssScore,
                ageInDays: days(between: alert.createdAt, and: ageReference),
                hasAssignee: !alert.assignedLogins.isEmpty,
                fixAvailable: alert.fixVersion != nil
            )
        }

        let codeScanningAlertSummaries: [CodeScanningAlertSummary] = allCodeScanningAlerts.map { alert in
            let repoName = alert.repository?.displayName ?? alert.repository?.name ?? "—"
            return CodeScanningAlertSummary(
                repoName: repoName,
                ruleId: alert.ruleId,
                ruleName: alert.ruleName,
                severity: alert.securitySeverityLevel,
                ageInDays: days(between: alert.createdAt, and: ageReference)
            )
        }

        let secretAlertSummaries: [SecretAlertSummary] = allSecretAlerts.map { alert in
            let repoName = alert.repository?.displayName ?? alert.repository?.name ?? "—"
            return SecretAlertSummary(
                repoName: repoName,
                secretTypeDisplayName: alert.secretTypeDisplayName,
                validity: alert.validity,
                publiclyLeaked: alert.publiclyLeaked,
                pushProtectionBypassed: alert.pushProtectionBypassed,
                multiRepo: alert.multiRepo
            )
        }

        let repoDetails: [SecurityRepoDetail] = repositories.map { repo in
            let repoCriticals = criticalAlerts.filter { $0.repository?.githubId == repo.githubId }
            let oldestAge = repoCriticals
                .map { days(between: $0.createdAt, and: ageReference) }
                .max()
            return SecurityRepoDetail(
                repoName: repo.displayName,
                openAlerts: repo.totalSecurityAlerts,
                criticalCount: repoCriticals.count,
                oldestCriticalAgeInDays: oldestAge
            )
        }

        let securityInput = SecurityInsightInput(
            weekInterval: weekInterval,
            dependabotSummaries: dependabotSummaries,
            codeScanningAlerts: codeScanningAlertSummaries,
            secretAlerts: secretAlertSummaries,
            repoDetails: repoDetails,
            currentWeekTotals: currentWeekTotals,
            priorWeekTotals: priorWeekTotals,
            weekHistory: weekHistory
        )

        let attention01: BriefingAttentionItem = {
            if let top = SecurityInsightGenerator.default.topInsight(securityInput) {
                return BriefingAttentionItem(
                    n: "1",
                    tone: top.tone,
                    title: top.briefingInsight.title,
                    meta: top.briefingInsight.meta,
                    actionLabel: top.briefingInsight.actionLabel,
                    insight: top.briefingInsight
                )
            }
            return BriefingAttentionItem(
                n: "1",
                tone: .neutral,
                title: "No security alerts this week.",
                meta: "All tracked repos clear",
                actionLabel: "See security →",
                insight: nil
            )
        }()

        let attention02: BriefingAttentionItem = {
            let unlinked = blockedMembers.filter { $0.neverContributed }
            let idle = blockedMembers.filter { !$0.neverContributed }

            // Unlinked: zero contributions on record — likely GitHub account not connected.
            if !unlinked.isEmpty {
                if unlinked.count == 1, let only = unlinked.first {
                    let firstName = only.name.split(separator: " ").first.map(String.init) ?? only.name
                    return BriefingAttentionItem(
                        n: "2",
                        tone: .red,
                        title: "**\(only.name)** may not have GitHub linked.",
                        meta: "\(only.team) — no contributions on record",
                        actionLabel: "DM \(firstName) →",
                        insight: nil
                    )
                }
                return BriefingAttentionItem(
                    n: "2",
                    tone: .red,
                    title: "**\(unlinked.count) members** may not have GitHub linked.",
                    meta: "No contributions detected — check account connections",
                    actionLabel: "Review members →",
                    insight: nil
                )
            }

            // Many idle: 3 or more members with past activity but nothing this week.
            if idle.count >= 3 {
                let longest = idle.max {
                    (Int($0.idleLabel.dropLast()) ?? 0) < (Int($1.idleLabel.dropLast()) ?? 0)
                }
                let longestDesc = longest.map { "\($0.name), \($0.idleLabel)" } ?? "—"
                return BriefingAttentionItem(
                    n: "2",
                    tone: .blue,
                    title: "**\(idle.count) members** haven't shipped this week.",
                    meta: "Longest idle: \(longestDesc)",
                    actionLabel: "View team →",
                    insight: nil
                )
            }

            // Single idle: 1–2 members quiet this week.
            if let first = idle.first {
                let firstName = first.name.split(separator: " ").first.map(String.init) ?? first.name
                return BriefingAttentionItem(
                    n: "2",
                    tone: .blue,
                    title: "\(first.name) idle \(first.idleLabel).",
                    meta: "\(first.team) team",
                    actionLabel: "DM \(firstName) →",
                    insight: nil
                )
            }

            return BriefingAttentionItem(
                n: "2",
                tone: .neutral,
                title: "Every tracked member shipped this week.",
                meta: "No idle members detected",
                actionLabel: "See team →",
                insight: nil
            )
        }()

        let attention03: BriefingAttentionItem = {
            if let low = lowestRepo, repoCounts.count > 1 {
                return BriefingAttentionItem(
                    n: "3",
                    tone: .neutral,
                    title: "Only \(low.count) PRs merged in \(low.name).",
                    meta: "Lowest volume of the week",
                    actionLabel: "See repo →",
                    insight: nil
                )
            }
            return BriefingAttentionItem(
                n: "3",
                tone: .neutral,
                title: "\(shippingTotal) PRs merged this week.",
                meta: "Across \(repositories.count) tracked repos",
                actionLabel: "See all →",
                insight: nil
            )
        }()

        // MARK: Verdicts
        let shippedVerdict: String
        if topRepoCount > 0 {
            shippedVerdict = "\(topRepoName) led the week with \(topRepoCount) merges."
        } else {
            shippedVerdict = "No merges recorded this week."
        }

        let activeRepoCount = repoCounts.filter { $0.count > 0 }.count
        let quietRepoCount = repoCounts.count - activeRepoCount
        let shippedSummary: String
        if shippingTotal > 0 {
            let showTop6 = activeRepoCount >= 6
            let topSum = showTop6
                ? repoCounts.prefix(6).reduce(0) { $0 + $1.count }
                : topRepoCount
            let topPct = Int((Double(topSum) / Double(shippingTotal) * 100).rounded())
            let topPart = showTop6 ? "The top 6 repos represent \(topPct)%" : "The top repo represents \(topPct)%"
            let quietPart = quietRepoCount == 0
                ? "0 repos with no PRs"
                : quietRepoCount == 1 ? "1 repo with no PRs" : "\(quietRepoCount) repos with no PRs"
            shippedSummary = "\(topPart) of all merged PRs this week · \(quietPart)"
        } else {
            shippedSummary = "No activity this week"
        }

        let blockedVerdict: String = switch blockedMembers.count {
        case 0: "Everyone shipped this week."
        case 1: "1 member went quiet this week."
        default: "\(blockedMembers.count) members went quiet this week."
        }

        let blockedSummary = "Heuristic: no commits this week · \(blockedMembers.count) of \(totalTracked) people flagged"

        let securityVerdict: String = criticalCount > 0
            ? "\(criticalCount) critical alerts need triage."
            : "Security is steady this week."

        // MARK: Repo health rows
        let repoHealth: [BriefingRepoHealth] = repositories
            .map { repo in
                let score = max(0, 100 - repo.totalSecurityAlerts * 5)
                return BriefingRepoHealth(
                    name: repo.displayName,
                    openAlerts: repo.totalSecurityAlerts,
                    score: score,
                    urgent: score < 50
                )
            }
            .sorted { $0.openAlerts > $1.openAlerts }

        // MARK: Hero
        let hero = BriefingHero(
            verdictA: shippingTotal > 0 ? "Shipping OK." : "Quiet week.",
            verdictB: criticalCount > 0 ? "Security is the story." : "No fires today.",
            highlightWord: criticalCount > 0 ? "Security" : "Shipping",
            highlight: criticalCount > 0 ? .red : .blue
        )

        return Briefing(
            generatedAt: Date(),
            volume: volume,
            weekRange: weekRange,
            hero: hero,
            attention: [attention01, attention02, attention03],
            kpis: BriefingKPIs(
                shipping: BriefingKPIShipping(value: shippingTotal, dailyCounts: shippingDailyCounts, priorWeekValue: priorWeekPRTotal > 0 ? priorWeekPRTotal : nil),
                security: BriefingKPISecurity(value: securityTotal, critical: criticalCount, dailyOpenTotals: securityDailyOpenTotals, priorWeekTotal: securityPriorTotal > 0 ? securityPriorTotal : nil),
                idle: BriefingKPIIdle(value: idleMembers.count, delta: idleDelta),
                medianMerge: medianMergeHours.map { BriefingKPIMedianMerge(value: $0, dailyMedians: dailyCycleTimeMedians, priorWeekValue: priorMedianMergeHours) },
                ciPass: ciPassPct.map { BriefingKPICIPass(value: $0, priorWeekValue: priorCIPassPct) },
                releases: releaseCount.map { BriefingKPIReleases(value: $0, priorWeekValue: priorReleaseCount) },
                prSize: medianPRSize.map { BriefingKPIPRSize(value: $0, dailyMedians: dailyPRSizeMedians, priorWeekValue: priorMedianPRSize) },
                activeContributors: totalTracked > 0
                    ? BriefingKPIActiveContributors(value: activeContributorCount, totalTracked: totalTracked, priorWeekValue: priorActiveCount)
                    : nil,
                mergeRate: mergeRate,
                stalePRCount: stalePRCount,
                timeToFirstReview: timeToFirstReview,
                unreviewedMergeRate: unreviewedMergeRate,
                hotfixRate: hotfixRate
            ),
            shipped: BriefingShipped(
                verdict: shippedVerdict,
                summary: shippedSummary,
                repos: repoCounts,
                contributors: contributors
            ),
            blocked: BriefingBlocked(
                verdict: blockedVerdict,
                summary: blockedSummary,
                members: blockedMembers
            ),
            security: BriefingSecurity(
                verdict: securityVerdict,
                buckets: [
                    BriefingSecurityBucket(
                        name: "Dependabot",
                        open: repositories.reduce(0) { $0 + $1.dependabotAlerts },
                        delta: 0,
                        critical: criticalCount
                    ),
                    BriefingSecurityBucket(
                        name: "Code Scanning",
                        open: repositories.reduce(0) { $0 + $1.codeScanningAlerts },
                        delta: 0,
                        critical: 0
                    ),
                    BriefingSecurityBucket(
                        name: "Secrets",
                        open: repositories.reduce(0) { $0 + $1.secretScanningAlerts },
                        delta: 0,
                        critical: 0
                    )
                ]
            ),
            repoHealth: repoHealth
        )
    }

    // MARK: - Private

    /// Returns a 7-element array of alert counts (one per day) for the given week interval.
    ///
    /// Each element is the number of alerts whose `createdAt` falls on that calendar day,
    /// where index 0 is the first day of `interval` and index 6 is the last.
    private static func dailyAlertCounts(dates: [Date], interval: DateInterval) -> [Int] {
        var counts = [Int](repeating: 0, count: 7)
        let cal = Calendar.current
        for date in dates where interval.contains(date) {
            let day = cal.dateComponents([.day], from: interval.start, to: date).day ?? 0
            if day >= 0 && day < 7 {
                counts[day] += 1
            }
        }
        return counts
    }

    /// Returns a 7-element array of cumulative open-alert totals for the given week interval.
    ///
    /// Index 0 is the running total at end of the first day; index 6 is the end of the last day.
    /// The baseline is all alerts created before `interval.start` (i.e. already open at week start).
    private static func dailyOpenTotals(dates: [Date], interval: DateInterval) -> [Int] {
        let baseline = dates.filter { $0 < interval.start }.count
        var totals = [Int](repeating: 0, count: 7)
        var cumulative = baseline
        for day in 0..<7 {
            let dayStart = interval.start.addingTimeInterval(Double(day) * 86_400)
            let dayEnd = interval.start.addingTimeInterval(Double(day + 1) * 86_400)
            cumulative += dates.filter { $0 >= dayStart && $0 < dayEnd }.count
            totals[day] = cumulative
        }
        return totals
    }

    /// Derives up-to-two uppercase initials from a display name.
    ///
    /// - Parameter name: A person's display name, e.g. `"Priya Shah"`.
    /// - Returns: The uppercased initials, e.g. `"PS"`. Empty input yields `"—"`.
    private static func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map { String($0) } }
        let joined = letters.joined().uppercased()
        return joined.isEmpty ? "—" : joined
    }
}

// MARK: - WeeklyReleasesResponse

/// The decoded response for a single ``BriefingQueries/recentReleases`` query.
private struct WeeklyReleasesResponse: Decodable, Sendable {

    struct Repository: Decodable, Sendable {
        struct Releases: Decodable, Sendable {
            struct Node: Decodable, Sendable {
                /// Null for draft releases; the decoder's `.iso8601` strategy parses this directly.
                let publishedAt: Date?
            }
            let nodes: [Node]
        }
        let releases: Releases
    }

    let repository: Repository?
}

// MARK: - CIPassRateResponse

/// The decoded response for a single page of a ``BriefingQueries/ciPassRate`` query.
private struct CIPassRateResponse: Decodable, Sendable {

    struct Search: Decodable, Sendable {

        struct PageInfo: Decodable, Sendable {
            let hasNextPage: Bool
            let endCursor: String?
        }

        struct PRNode: Decodable, Sendable {

            struct Commits: Decodable, Sendable {

                struct CommitNode: Decodable, Sendable {

                    struct Commit: Decodable, Sendable {

                        struct StatusCheckRollup: Decodable, Sendable {
                            /// `"SUCCESS"`, `"FAILURE"`, `"PENDING"`, `"ERROR"`, or `"EXPECTED"`.
                            let state: String
                        }

                        let statusCheckRollup: StatusCheckRollup?
                    }

                    let commit: Commit
                }

                let nodes: [CommitNode]
            }

            /// Nil when the search node is not a PullRequest (shouldn't happen with `is:pr`).
            let commits: Commits?
        }

        let pageInfo: PageInfo
        let nodes: [PRNode]
    }

    let search: Search
}

// MARK: - WeeklyPRCountResponse

/// The decoded response for a single ``BriefingQueries/weeklyMergedPRCount`` query.
private struct WeeklyPRCountResponse: Decodable, Sendable {

    /// The nested `search` field containing only `issueCount`.
    struct Search: Decodable, Sendable {

        /// The total number of merged PRs matching the search query.
        let issueCount: Int
    }

    /// The `search` field of the response envelope.
    let search: Search
}
