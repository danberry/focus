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
    func generate(
        scope: BriefingScope = .all,
        in context: ModelContext,
        onPhase: ((BriefingLoadingPhase) -> Void)? = nil
    ) async -> Briefing {
        onPhase?(.loadingData)

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

        // Snapshot open PR creation dates as value types before the first await — applyOpenPRs()
        // can delete OpenPullRequest objects at any suspension point, invalidating live references.
        let openPRCreatedDates: [Date] = scopedRepos.flatMap { $0.openPullRequests.map(\.createdAt) }

        // Snapshot daily contributions as value types before the first await —
        // ContributionService.syncDailyContributions() deletes DailyContribution objects at any
        // suspension point, invalidating live SwiftData references.
        let memberDailyContributions: [ObjectIdentifier: [(date: Date, count: Int)]] =
            Dictionary(uniqueKeysWithValues: scopedMembers.map { m in
                (ObjectIdentifier(m), m.dailyContributions.map { ($0.date, $0.count) })
            })

        var cal = Calendar.current
        cal.firstWeekday = 1
        let priorWeekStart = weekInterval.start.addingTimeInterval(-1)
        let priorGhRange = cal.dateInterval(of: .weekOfYear, for: priorWeekStart)
            .map { githubDateRange(for: $0) } ?? ""

        let priorWeekInterval = cal.dateInterval(of: .weekOfYear, for: priorWeekStart) ?? weekInterval
        let displayNames: [String] = scopedRepos.map(\.displayName)

        // Check whether we already have a snapshot for the prior week — if so, skip its
        // paginated GitHub fetch entirely and reconstruct the metrics from SwiftData.
        let fingerprint = repoFingerprint(for: repoKeys)
        let priorCacheHit = loadCachedPRMetrics(weekStart: priorWeekInterval.start, fingerprint: fingerprint, context: context)

        onPhase?(.fetchingMetrics)
        async let metricsFetch = fetchMergedPRMetrics(repoKeys: repoKeys, interval: weekInterval)
        async let priorMetricsFetch = fetchMergedPRMetricsOrCached(repoKeys: repoKeys, interval: priorWeekInterval, cached: priorCacheHit)
        async let releaseCountsFetch = fetchBatchedReleaseCounts(repoKeys: repoKeys, since: weekInterval.start, until: weekInterval.end, priorSince: priorWeekStart, priorUntil: weekInterval.start)
        // Five count-only searches batched into a single GraphQL request.
        async let countsFetch = fetchBatchedSearchCounts(repoKeys: repoKeys, queries: [
            (qualifier: "is:pr created:", range: ghRange),
            (qualifier: "is:pr created:", range: priorGhRange),
            (qualifier: "is:issue created:", range: ghRange),
            (qualifier: "is:issue is:closed closed:", range: ghRange),
            (qualifier: "is:issue is:closed closed:", range: priorGhRange)
        ])
        async let dismissedCountsFetch = fetchDismissedCountsOrEmpty(repoKeys: repoKeys, displayNames: displayNames, since: weekInterval.start, until: weekInterval.end)
        let metrics = await metricsFetch
        let priorMetrics = await priorMetricsFetch
        let (releaseCount, priorReleaseCount) = await releaseCountsFetch
        let counts = await countsFetch
        let repoClosedCounts = await dismissedCountsFetch

        // Persist the current-week metrics so next week's briefing can skip its prior-week fetch.
        persistPRSnapshot(weekStart: weekInterval.start, fingerprint: fingerprint, metrics: metrics, context: context)

        let prCounts = Dictionary(
            metrics.repoCounts.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: +
        )
        // Prior-week merged total comes from the detailed fetch — no separate count query needed.
        let priorWeekPRTotal = priorMetrics.totalMerged
        let openedPRTotal = counts[0]
        let priorOpenedPRTotal = counts[1]
        let openedIssueTotal = counts[2]
        let closedIssueTotal = counts[3]
        let priorClosedIssueTotal = counts[4]
        let unreviewedCount = metrics.unreviewedCount
        let totalPRCount = metrics.totalPRCount
        let priorUnreviewedCount = priorMetrics.unreviewedCount
        let priorTotalPRCount = priorMetrics.totalPRCount

        onPhase?(.fetchingSecurityAlerts)
        let criticalDescriptor = FetchDescriptor<DependabotAlert>(
            predicate: #Predicate { $0.severity == "critical" }
        )
        let criticalAlerts = (try? context.fetch(criticalDescriptor)) ?? []

        // Fetch the full alert sets once; they're reused for the sparkline,
        // the security insight generator, and the per-repo rollups.
        // Code scanning only includes open alerts; dismissed and fixed records are retained
        // for history but excluded from security insight rules and badge counts.
        let allDependabotAlerts = (try? context.fetch(FetchDescriptor<DependabotAlert>())) ?? []
        var codeScanningDescriptor = FetchDescriptor<CodeScanningAlert>()
        codeScanningDescriptor.predicate = #Predicate { $0.state == "open" }
        let allCodeScanningAlerts = (try? context.fetch(codeScanningDescriptor)) ?? []
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

        // Tier 3: dismissed counts already fetched in parallel above.
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

        onPhase?(.assembling)
        return assemble(
            weekInterval: weekInterval,
            weekRange: weekRange,
            repositories: scopedRepos,
            prCounts: prCounts,
            priorWeekPRTotal: priorWeekPRTotal,
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
            ciPassPct: metrics.ciPassPct,
            priorCIPassPct: priorMetrics.ciPassPct,
            releaseCount: releaseCount,
            priorReleaseCount: priorReleaseCount,
            openedPRTotal: openedPRTotal,
            priorOpenedPRTotal: priorOpenedPRTotal,
            openedIssueTotal: openedIssueTotal,
            closedIssueTotal: closedIssueTotal,
            priorClosedIssueTotal: priorClosedIssueTotal,
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
            memberDailyContributions: memberDailyContributions,
            openPRCreatedDates: openPRCreatedDates,
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

    /// Fetches dismissed Dependabot alert counts, or returns an empty dictionary when
    /// no REST client is configured (Tier 3 rules no-op gracefully in that case).
    private func fetchDismissedCountsOrEmpty(
        repoKeys: [(owner: String, name: String)],
        displayNames: [String],
        since: Date,
        until: Date
    ) async -> [String: Int] {
        guard let restClient = rest else { return [:] }
        let secService = SecurityService(rest: restClient)
        return await fetchDismissedCounts(
            repoKeys: repoKeys,
            displayNames: displayNames,
            securityService: secService,
            since: since,
            until: until
        )
    }

    // MARK: - PR Fetch

    /// Combines all repo qualifiers into a single GitHub Search query and returns the total count.
    ///
    /// Used for metrics that only need a cross-repo total (not a per-repo breakdown).
    /// Each call makes exactly one GraphQL request regardless of repo count.
    ///
    /// - Parameters:
    ///   - repoKeys: The repositories to include in the combined query.
    ///   - qualifier: The search qualifier prefix, e.g. `"is:pr created:"`.
    ///   - range: The date range string appended directly after the qualifier.
    /// - Returns: The total `issueCount` across all repos, or `0` on any error.
    func fetchCombinedSearchCount(
        repoKeys: [(owner: String, name: String)],
        qualifier: String,
        range: String
    ) async -> Int {
        guard !repoKeys.isEmpty else { return 0 }
        let repos = repoKeys.map { "repo:\($0.owner)/\($0.name)" }.joined(separator: " ")
        let q = "\(repos) \(qualifier)\(range)"
        do {
            let response: WeeklyPRCountResponse = try await graphQL.execute(
                query: BriefingQueries.weeklyMergedPRCount,
                variables: ["q": q],
                responseType: WeeklyPRCountResponse.self
            )
            return response.search.issueCount
        } catch {
            return 0
        }
    }

    /// Fetches merged PR data for the week and derives all computed metrics in a single pass.
    ///
    /// Returns ``PRMetrics/empty`` when there are no repos, no PRs, or on network error.
    /// CI pass rate is computed from the same PR nodes — no separate network request needed.
    private func fetchMergedPRMetrics(
        repoKeys: [(owner: String, name: String)],
        interval: DateInterval
    ) async -> PRMetrics {
        guard !repoKeys.isEmpty else { return .empty }
        let service = MergedPRReportService(graphQL: graphQL)
        let endDate = interval.end.addingTimeInterval(-1)
        guard let prsByRepo = try? await service.fetchMergedPRs(for: repoKeys, from: interval.start, to: endDate) else {
            return .empty
        }
        let (unreviewedCount, totalPRCount) = computeUnreviewedStats(from: prsByRepo)
        return PRMetrics(
            medianHours: computeMedianMergeHours(from: prsByRepo),
            dailyCounts: computeDailyCounts(from: prsByRepo, interval: interval),
            medianPRSize: computeMedianPRSize(from: prsByRepo),
            dailyPRSizeMedians: computeDailyPRSizeMedians(from: prsByRepo, interval: interval),
            dailyCycleTimeMedians: computeDailyCycleTimeMedians(from: prsByRepo, interval: interval),
            medianFirstReviewHours: computeMedianFirstReviewHours(from: prsByRepo),
            dailyFirstReviewMedians: computeDailyFirstReviewMedians(from: prsByRepo, interval: interval),
            hotfixCount: computeHotfixCount(from: prsByRepo),
            totalMerged: prsByRepo.values.reduce(0) { $0 + $1.count },
            unreviewedCount: unreviewedCount,
            totalPRCount: totalPRCount,
            ciPassPct: computeCIPassRate(from: prsByRepo),
            repoCounts: prsByRepo.mapValues(\.count)
        )
    }

    /// Returns cached metrics when available, otherwise fetches from GitHub.
    ///
    /// Wrapping the conditional in an `async` function lets the caller use `async let`
    /// so it runs concurrently with the current-week fetch regardless of cache state.
    private func fetchMergedPRMetricsOrCached(
        repoKeys: [(owner: String, name: String)],
        interval: DateInterval,
        cached: PRMetrics?
    ) async -> PRMetrics {
        if let cached { return cached }
        return await fetchMergedPRMetrics(repoKeys: repoKeys, interval: interval)
    }

    /// Derives a stable fingerprint for a set of repositories.
    ///
    /// Sorting ensures the fingerprint is order-independent; joining with `","` produces
    /// a string that can be stored in and queried from SwiftData.
    private func repoFingerprint(for repoKeys: [(owner: String, name: String)]) -> String {
        repoKeys.map { "\($0.owner)/\($0.name)" }.sorted().joined(separator: ",")
    }

    /// Loads cached PR metrics for the given week and repo fingerprint from SwiftData.
    ///
    /// Returns `nil` on a cache miss so the caller can fall back to a live fetch.
    @MainActor
    private func loadCachedPRMetrics(weekStart: Date, fingerprint: String, context: ModelContext) -> PRMetrics? {
        let nextWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
        let results = try? context.fetch(FetchDescriptor<PRWeeklySnapshot>(
            predicate: #Predicate { $0.weekStart >= weekStart && $0.weekStart < nextWeekStart }
        ))
        guard let snapshot = results?.first(where: { $0.repoFingerprint == fingerprint }) else { return nil }
        return PRMetrics(
            medianHours: snapshot.medianHours,
            dailyCounts: snapshot.dailyCounts,
            medianPRSize: snapshot.medianPRSize,
            dailyPRSizeMedians: snapshot.dailyPRSizeMedians,
            dailyCycleTimeMedians: snapshot.dailyCycleTimeMedians,
            medianFirstReviewHours: snapshot.medianFirstReviewHours,
            dailyFirstReviewMedians: snapshot.dailyFirstReviewMedians,
            hotfixCount: snapshot.hotfixCount,
            totalMerged: snapshot.totalMerged,
            unreviewedCount: snapshot.unreviewedCount,
            totalPRCount: snapshot.totalPRCount,
            ciPassPct: snapshot.ciPassPct,
            repoCounts: snapshot.repoCounts
        )
    }

    /// Writes or updates the ``PRWeeklySnapshot`` for the given week and fingerprint.
    @MainActor
    private func persistPRSnapshot(weekStart: Date, fingerprint: String, metrics: PRMetrics, context: ModelContext) {
        let nextWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
        let results = try? context.fetch(FetchDescriptor<PRWeeklySnapshot>(
            predicate: #Predicate { $0.weekStart >= weekStart && $0.weekStart < nextWeekStart }
        ))
        if let snapshot = results?.first(where: { $0.repoFingerprint == fingerprint }) {
            snapshot.medianHours = metrics.medianHours
            snapshot.dailyCounts = metrics.dailyCounts
            snapshot.medianPRSize = metrics.medianPRSize
            snapshot.dailyPRSizeMedians = metrics.dailyPRSizeMedians
            snapshot.dailyCycleTimeMedians = metrics.dailyCycleTimeMedians
            snapshot.medianFirstReviewHours = metrics.medianFirstReviewHours
            snapshot.dailyFirstReviewMedians = metrics.dailyFirstReviewMedians
            snapshot.hotfixCount = metrics.hotfixCount
            snapshot.totalMerged = metrics.totalMerged
            snapshot.unreviewedCount = metrics.unreviewedCount
            snapshot.totalPRCount = metrics.totalPRCount
            snapshot.ciPassPct = metrics.ciPassPct
            snapshot.repoCountsJSON = try? JSONEncoder().encode(metrics.repoCounts)
        } else {
            context.insert(PRWeeklySnapshot(
                weekStart: weekStart,
                repoFingerprint: fingerprint,
                medianHours: metrics.medianHours,
                dailyCounts: metrics.dailyCounts,
                medianPRSize: metrics.medianPRSize,
                dailyPRSizeMedians: metrics.dailyPRSizeMedians,
                dailyCycleTimeMedians: metrics.dailyCycleTimeMedians,
                medianFirstReviewHours: metrics.medianFirstReviewHours,
                dailyFirstReviewMedians: metrics.dailyFirstReviewMedians,
                hotfixCount: metrics.hotfixCount,
                totalMerged: metrics.totalMerged,
                unreviewedCount: metrics.unreviewedCount,
                totalPRCount: metrics.totalPRCount,
                ciPassPct: metrics.ciPassPct,
                repoCounts: metrics.repoCounts
            ))
        }
        try? context.save()
    }

    /// Executes multiple GitHub search count queries in a single batched GraphQL request.
    ///
    /// Each element of `queries` maps to one aliased `search` field. Returns an array of
    /// `issueCount` values at the same indices as `queries`, defaulting to `0` on any error.
    func fetchBatchedSearchCounts(
        repoKeys: [(owner: String, name: String)],
        queries: [(qualifier: String, range: String)]
    ) async -> [Int] {
        guard !repoKeys.isEmpty && !queries.isEmpty else { return Array(repeating: 0, count: queries.count) }
        let repos = repoKeys.map { "repo:\($0.owner)/\($0.name)" }.joined(separator: " ")
        let aliases = queries.enumerated().map { i, q in
            let search = "\(repos) \(q.qualifier)\(q.range)"
            let escaped = search
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "s\(i): search(query: \"\(escaped)\", type: ISSUE, first: 1) { issueCount }"
        }.joined(separator: " ")
        guard let response = try? await graphQL.execute(
            query: "{ \(aliases) }",
            variables: nil,
            responseType: [String: SearchCountResult].self
        ) else { return Array(repeating: 0, count: queries.count) }
        return queries.indices.map { response["s\($0)"]?.issueCount ?? 0 }
    }

    private func computeCIPassRate(from prsByRepo: [String: [MergedPR]]) -> Int? {
        var withChecks = 0
        var passed = 0
        for pr in prsByRepo.values.flatMap({ $0 }) {
            guard let state = pr.ciState else { continue }
            withChecks += 1
            if state == "SUCCESS" { passed += 1 }
        }
        guard withChecks > 0 else { return nil }
        return Int((Double(passed) / Double(withChecks) * 100).rounded())
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

    /// Fetches the last 20 releases for all repositories in a single aliased GraphQL request,
    /// then counts releases falling within both the current and prior week windows client-side.
    ///
    /// Replaces two separate N-request fan-outs with one batched query.
    ///
    /// - Parameters:
    ///   - repoKeys: The repositories to query.
    ///   - since: Start of the current week window (inclusive).
    ///   - until: End of the current week window (exclusive).
    ///   - priorSince: Start of the prior week window (inclusive).
    ///   - priorUntil: End of the prior week window (exclusive).
    /// - Returns: A tuple of `(current, prior)` release counts, or `(nil, nil)` when empty or on error.
    func fetchBatchedReleaseCounts(
        repoKeys: [(owner: String, name: String)],
        since: Date,
        until: Date,
        priorSince: Date,
        priorUntil: Date
    ) async -> (current: Int?, prior: Int?) {
        guard !repoKeys.isEmpty else { return (nil, nil) }

        let fields = repoKeys.enumerated().map { i, key in
            "r\(i): repository(owner: \"\(key.owner)\", name: \"\(key.name)\") { releases(first: 20, orderBy: {field: CREATED_AT, direction: DESC}) { nodes { publishedAt } } }"
        }.joined(separator: " ")

        guard let response = try? await graphQL.execute(
            query: "{ \(fields) }",
            variables: nil,
            responseType: [String: BatchedReleasesResult].self
        ) else { return (nil, nil) }

        var current = 0
        var prior = 0
        for (i, _) in repoKeys.enumerated() {
            for node in response["r\(i)"]?.releases.nodes ?? [] {
                guard let pub = node.publishedAt else { continue }
                if pub >= since && pub < until { current += 1 }
                if pub >= priorSince && pub < priorUntil { prior += 1 }
            }
        }
        return (current, prior)
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
        openedIssueTotal: Int,
        closedIssueTotal: Int,
        priorClosedIssueTotal: Int,
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
        memberDailyContributions: [ObjectIdentifier: [(date: Date, count: Int)]],
        openPRCreatedDates: [Date],
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
        let staleDate = weekInterval.end.addingTimeInterval(-Double(stalePRThresholdDays) * 86_400)
        let staleDates = openPRCreatedDates.filter { $0 < staleDate }
        let priorStaleDate: Date = {
            var cal = Calendar.current
            cal.firstWeekday = 1
            if let priorEnd = cal.dateInterval(of: .weekOfYear, for: weekInterval.start.addingTimeInterval(-1))?.end {
                return priorEnd.addingTimeInterval(-Double(stalePRThresholdDays) * 86_400)
            }
            return staleDate
        }()
        let priorStalePRCount = openPRCreatedDates.filter { $0 < priorStaleDate }.count
        let oldestStalePRAgeDays: Int? = staleDates
            .map { Calendar.current.dateComponents([.day], from: $0, to: weekInterval.end).day ?? 0 }
            .max()
        let stalePRCount: BriefingKPIStalePRCount? = !openPRCreatedDates.isEmpty ? BriefingKPIStalePRCount(
            value: staleDates.count,
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

        // MARK: Review Load
        let reviewLoad: BriefingKPIReviewLoad? = {
            let pairs: [(login: String, count: Int)] = members.compactMap { member in
                guard let login = member.githubLogin else { return nil }
                let total = member.contributions.reduce(0) { $0 + $1.reviews }
                return total > 0 ? (login: login, count: total) : nil
            }
            guard !pairs.isEmpty else { return nil }
            let sorted = pairs.sorted { $0.count > $1.count }.prefix(7)
            let maxCount = Double(sorted.first?.count ?? 1)
            let reviewers = sorted.map { (login: $0.login, normalizedCount: Double($0.count) / maxCount) }
            return BriefingKPIReviewLoad(reviewers: reviewers)
        }()

        // MARK: Issue Velocity
        let issueVelocity: BriefingKPIIssueVelocity? = repositories.isEmpty ? nil : BriefingKPIIssueVelocity(
            opened: openedIssueTotal,
            closed: closedIssueTotal,
            dailyClosedCounts: [Int](repeating: 0, count: 7),
            priorWeekClosed: priorClosedIssueTotal > 0 ? priorClosedIssueTotal : nil
        )

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

            let contribs = memberDailyContributions[ObjectIdentifier(member)] ?? []
            let weekSum = contribs
                .filter { weekInterval.contains($0.date) }
                .reduce(0) { $0 + $1.count }

            if weekSum == 0 {
                idleMembers.append(member)

                let lastActive = contribs
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
                return (memberDailyContributions[ObjectIdentifier(member)] ?? [])
                    .filter { prior.contains($0.date) }
                    .reduce(0) { $0 + $1.count } == 0
            }.count
        } ?? 0
        let idleDelta = idleMembers.count - priorIdleCount

        // MARK: Shipped — repo ranking
        var repoRanking: [(repo: SavedRepository, count: Int)] = repositories.map { repo in
            (repo, prCounts["\(repo.owner)/\(repo.name)".lowercased()] ?? 0)
        }
        repoRanking.sort { $0.count > $1.count }
        let repoCounts: [BriefingRepoCount] = repoRanking.enumerated().map { index, pair in
            BriefingRepoCount(name: pair.repo.displayName, count: pair.count, flag: index == 0)
        }

        let topRepoName = repoCounts.first?.name ?? "—"
        let topRepoCount = repoCounts.first?.count ?? 0
        let activeRepoRanking = repoRanking.filter { !$0.repo.isInMaintenance }
        let lowestRepo = activeRepoRanking
            .min { $0.count < $1.count }
            .map { BriefingRepoCount(name: $0.repo.displayName, count: $0.count, flag: false) }

        // MARK: Shipped — contributors (derived from Members' weekly contribution sums)
        var memberWeeklyCounts: [(member: Member, count: Int)] = []
        for member in members {
            let weekSum = (memberDailyContributions[ObjectIdentifier(member)] ?? [])
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
                return (memberDailyContributions[ObjectIdentifier(member)] ?? [])
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
            if let low = lowestRepo, activeRepoRanking.count > 1 {
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

        let activeRepoCount = activeRepoRanking.filter { $0.count > 0 }.count
        let quietRepoCount = activeRepoRanking.filter { $0.count == 0 }.count
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

        // Partition flagged members into the three inactivity categories.
        let unlinkedMembers = blockedMembers.filter { $0.neverContributed }
        let idleThisWeekMembers = blockedMembers.filter { member in
            guard !member.neverContributed else { return false }
            let days = member.idleLabel.hasSuffix("d")
                ? Int(member.idleLabel.dropLast()) ?? Int.max
                : Int.max
            return days <= 14
        }
        let idleLongTermMembers = blockedMembers.filter { member in
            guard !member.neverContributed else { return false }
            let days = member.idleLabel.hasSuffix("d")
                ? Int(member.idleLabel.dropLast()) ?? Int.max
                : Int.max
            return days > 14
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
                hotfixRate: hotfixRate,
                reviewLoad: reviewLoad,
                issueVelocity: issueVelocity
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
                unlinked: unlinkedMembers,
                idleThisWeek: idleThisWeekMembers,
                idleLongTerm: idleLongTermMembers
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

// MARK: - BatchedReleasesResult

/// One entry in the aliased ``BriefingService/fetchBatchedReleaseCounts`` response.
private struct BatchedReleasesResult: Decodable, Sendable {

    struct ReleasesConnection: Decodable, Sendable {
        struct Node: Decodable, Sendable {
            let publishedAt: Date?
        }
        let nodes: [Node]
    }

    let releases: ReleasesConnection
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

// MARK: - SearchCountResult

/// One aliased field in the ``BriefingService/fetchBatchedSearchCounts`` response.
private struct SearchCountResult: Decodable, Sendable {
    let issueCount: Int
}

// MARK: - PRMetrics

/// The computed metrics derived from a week of merged PR data.
///
/// Used as the return type of ``BriefingService/fetchMergedPRMetrics(repoKeys:interval:)``
/// and as the in-memory representation of a ``PRWeeklySnapshot``.
private struct PRMetrics: Sendable {
    var medianHours: Int?
    var dailyCounts: [Int]
    var medianPRSize: Int?
    var dailyPRSizeMedians: [Int]
    var dailyCycleTimeMedians: [Int]
    var medianFirstReviewHours: Int?
    var dailyFirstReviewMedians: [Int]
    var hotfixCount: Int
    var totalMerged: Int
    var unreviewedCount: Int
    var totalPRCount: Int
    var ciPassPct: Int?
    var repoCounts: [String: Int]

    static let empty = PRMetrics(
        medianHours: nil,
        dailyCounts: Array(repeating: 0, count: 7),
        medianPRSize: nil,
        dailyPRSizeMedians: Array(repeating: 0, count: 7),
        dailyCycleTimeMedians: Array(repeating: 0, count: 7),
        medianFirstReviewHours: nil,
        dailyFirstReviewMedians: Array(repeating: 0, count: 7),
        hotfixCount: 0,
        totalMerged: 0,
        unreviewedCount: 0,
        totalPRCount: 0,
        ciPassPct: nil,
        repoCounts: [:]
    )
}
