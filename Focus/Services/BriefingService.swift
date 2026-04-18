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

    // MARK: - Init

    /// Creates a briefing service backed by the given GraphQL client.
    ///
    /// - Parameter graphQL: The client used to execute search queries against the GitHub GraphQL API.
    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Generation

    /// Builds a ``Briefing`` for the previous calendar week.
    ///
    /// The returned briefing combines fresh merged PR counts (fetched in parallel) with
    /// security alerts and member contributions read from the supplied SwiftData context.
    ///
    /// If week computation or repository fetching fails, returns ``Briefing/placeholder``.
    ///
    /// - Parameter context: The SwiftData model context used to read the local graph.
    /// - Returns: An assembled ``Briefing`` for the previous week.
    @MainActor
    func generate(in context: ModelContext) async -> Briefing {
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

        // Snapshot Sendable (owner, repo) pairs for the non-isolated fetch fan-out.
        let repoKeys: [(owner: String, name: String)] = repositories.map { ($0.owner, $0.name) }
        let prCounts = await fetchAllPRCounts(repoKeys: repoKeys, range: ghRange)

        let criticalDescriptor = FetchDescriptor<DependabotAlert>(
            predicate: #Predicate { $0.severity == "critical" }
        )
        let criticalAlerts = (try? context.fetch(criticalDescriptor)) ?? []

        let members = (try? context.fetch(FetchDescriptor<Member>())) ?? []

        return assemble(
            weekInterval: weekInterval,
            weekRange: weekRange,
            repositories: repositories,
            prCounts: prCounts,
            criticalAlerts: criticalAlerts,
            members: members
        )
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
        cal.firstWeekday = 2
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
        criticalAlerts: [DependabotAlert],
        members: [Member]
    ) -> Briefing {
        let volume = Calendar.current.component(.weekOfYear, from: weekInterval.start)

        // MARK: Shipping
        let shippingTotal = prCounts.values.reduce(0, +)
        // TODO: Replace placeholder spark with real historical daily merge counts.
        let shippingSpark: [Double] = [0.3, 0.5, 0.6, 0.4, 0.7, 0.8, 0.6, 0.9, 0.7, 1.0]

        // MARK: Security
        let securityTotal = repositories.reduce(0) { $0 + $1.totalSecurityAlerts }
        let criticalCount = criticalAlerts.count
        // TODO: Replace placeholder spark with real historical daily open-alert counts.
        let securitySpark: [Double] = [0.4, 0.5, 0.5, 0.6, 0.7, 0.7, 0.8, 0.8, 0.9, 1.0]

        // MARK: Members — idle detection
        let weekEnd = weekInterval.end
        var idleMembers: [Member] = []
        var memberIdleLabels: [ObjectIdentifier: String] = [:]

        for member in members {
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

        // TODO: Replace idle delta with real prior-week comparison.
        let idleDelta = 0

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
        let lowestRepo = repoCounts.min { $0.count < $1.count }

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
                count: pair.count
            )
        }

        // MARK: Blocked members
        let blockedMembers: [BriefingBlockedMember] = idleMembers.map { member in
            let label = memberIdleLabels[ObjectIdentifier(member)] ?? "—"
            let urgent = label.hasSuffix("d") && (Int(label.dropLast()) ?? 0) >= 5
            return BriefingBlockedMember(
                initials: Self.initials(from: member.name),
                name: member.name,
                team: member.team?.name ?? "—",
                idleLabel: label,
                recommendation: "No commits this week. Consider a check-in.",
                urgent: urgent,
                githubLogin: member.githubLogin
            )
        }

        // MARK: Attention items — §01 security, §02 idle, §03 shipping
        var criticalPerRepo: [(repo: SavedRepository, critical: Int)] = []
        for repo in repositories {
            let count = criticalAlerts.filter { $0.repository?.githubId == repo.githubId }.count
            criticalPerRepo.append((repo, count))
        }
        let repoByMostCritical = criticalPerRepo.max { $0.critical < $1.critical }

        let attention01: BriefingAttentionItem = {
            if let top = repoByMostCritical, top.critical > 0 {
                return BriefingAttentionItem(
                    n: "01",
                    tone: .red,
                    title: "\(top.critical) critical alerts open in `\(top.repo.displayName)`.",
                    meta: "Escalate to security review",
                    actionLabel: "Open alerts →"
                )
            }
            return BriefingAttentionItem(
                n: "01",
                tone: .neutral,
                title: "No critical security alerts this week.",
                meta: "All tracked repos clear",
                actionLabel: "See security →"
            )
        }()

        let attention02: BriefingAttentionItem = {
            if let first = blockedMembers.first {
                return BriefingAttentionItem(
                    n: "02",
                    tone: .blue,
                    title: "\(first.name) idle \(first.idleLabel).",
                    meta: "\(first.team) team",
                    actionLabel: "DM \(first.name.split(separator: " ").first.map(String.init) ?? first.name) →"
                )
            }
            return BriefingAttentionItem(
                n: "02",
                tone: .neutral,
                title: "Every tracked member shipped this week.",
                meta: "No idle members detected",
                actionLabel: "See team →"
            )
        }()

        let attention03: BriefingAttentionItem = {
            if let low = lowestRepo, repoCounts.count > 1 {
                return BriefingAttentionItem(
                    n: "03",
                    tone: .neutral,
                    title: "Only \(low.count) PRs merged in `\(low.name)`.",
                    meta: "Lowest volume of the week",
                    actionLabel: "See repo →"
                )
            }
            return BriefingAttentionItem(
                n: "03",
                tone: .neutral,
                title: "\(shippingTotal) PRs merged this week.",
                meta: "Across \(repositories.count) tracked repos",
                actionLabel: "See all →"
            )
        }()

        // MARK: Verdicts
        let shippedVerdict: String
        if topRepoCount > 0 {
            shippedVerdict = "`\(topRepoName)` led the week with \(topRepoCount) merges."
        } else {
            shippedVerdict = "No merges recorded this week."
        }

        let blockedVerdict: String = switch blockedMembers.count {
        case 0: "Everyone shipped this week."
        case 1: "1 member went quiet this week."
        default: "\(blockedMembers.count) members went quiet this week."
        }

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
                shipping: BriefingKPIShipping(value: shippingTotal, spark: shippingSpark),
                security: BriefingKPISecurity(value: securityTotal, critical: criticalCount, spark: securitySpark),
                idle: BriefingKPIIdle(value: idleMembers.count, delta: idleDelta),
                reviewMedianHours: nil,
                ciPassPct: nil,
                deploys: nil
            ),
            shipped: BriefingShipped(
                verdict: shippedVerdict,
                repos: repoCounts,
                contributors: contributors
            ),
            blocked: BriefingBlocked(
                verdict: blockedVerdict,
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
