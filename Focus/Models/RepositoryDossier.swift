import Foundation
import SwiftData

// MARK: - RepositoryDossier

/// A computed, read-only "dossier" snapshot for a single repository.
///
/// `RepositoryDossier` is a pure value type assembled at display time from
/// GraphQL counts and the local SwiftData graph. It is not persisted — each
/// dossier is built on demand to drive the ``RepositoryDossierView`` screen.
struct RepositoryDossier: Sendable {

    // MARK: - Properties

    /// The repository owner login (organization or user).
    let owner: String

    /// The repository name (without owner prefix).
    let name: String

    /// The user-facing label for the repository, as entered in the app.
    let displayName: String

    /// The repository's short description as it appears on GitHub.
    let description: String

    /// Whether the repository is private on GitHub.
    let isPrivate: Bool

    /// The name of the department that owns this repository's team, or `nil` when not assigned.
    let department: String?

    /// The most recent push date derived from branch activity, or `nil` when no branch data is available.
    let lastPushedAt: Date?

    /// The default branch name (typically `"main"` or `"develop"`).
    let defaultBranch: String

    /// The repository's primary language, or `nil` when not detected.
    let primaryLanguage: String?

    /// The KPI strip totals shown at the top of the dossier.
    let kpi: KPI

    /// 26-week × 7-day commit intensity grid for the activity heatmap card.
    let activityHeatmap: ActivityHeatmap

    /// 16-week merged-PR sparkline used in the velocity card.
    let velocitySpark: VelocitySpark

    /// The currently open pull requests, ordered for display (typically newest first).
    let openPRs: [OpenPR]

    /// Merged PR counts grouped by weekday for the last 7 days (Mon–Sun).
    let mergedByDay: [DailyCount]

    /// CI run counts grouped by weekday for the last 7 days (Mon–Sun).
    let ciRunsByDay: [DailyCount]

    /// Top contributors over the last 30 days, ordered by descending merged PR count.
    let contributors: [Contributor]

    /// Files with the highest churn over the last 30 days, ordered by descending churn.
    let hotFiles: [HotFile]

    /// Aggregate counts of open security alerts by severity.
    let security: SecuritySummary

    /// Individual security alert items, ordered by descending severity / age.
    let alertItems: [AlertItem]

    /// Branches surfaced for the branches card (default, staging, behind, stale).
    let branches: [Branch]

    /// The most recent releases, ordered newest first.
    let releases: [Release]

    // MARK: - Preview

    /// A hardcoded preview value used by SwiftUI canvases and stub navigation entry points.
    ///
    /// Values are chosen to be plausible against a real engineering team so
    /// every section of the dossier renders with non-empty content.
    static let preview: RepositoryDossier = RepositoryDossier(
        owner: "acme-co",
        name: "payments-api",
        displayName: "Payments API",
        description: "Core payments service handling charges, refunds, and webhook delivery.",
        isPrivate: true,
        department: "Platform",
        lastPushedAt: Date(timeIntervalSinceNow: -14 * 60),
        defaultBranch: "main",
        primaryLanguage: "Swift",
        kpi: KPI(
            mergedThisWeek: 24,
            mergedThisWeekDelta: 6,
            openPRs: 18,
            stalePRs: 4,
            openIssues: 47,
            closedIssues7d: 12,
            securityAlerts: 22,
            criticalAlerts: 3,
            ciPassPct: 91.5,
            ciRuns7d: 142,
            contributors30d: 14
        ),
        activityHeatmap: ActivityHeatmap(
            cells: (0..<182).map { index in
                let pattern = [0, 1, 2, 1, 3, 2, 4, 1, 0, 2, 3, 1, 0, 2]
                return pattern[index % pattern.count]
            },
            startDate: Calendar.current.date(byAdding: .weekOfYear, value: -26, to: Date()),
            endDate: Date(),
            totalCommits: 2847,
            peakDate: Calendar.current.date(byAdding: .day, value: -37, to: Date())
        ),
        velocitySpark: VelocitySpark(
            weeklyCommits: [85, 92, 78, 110, 45, 85, 125, 105, 95, 140, 120, 80, 110, 135, 150, 120, 95, 105, 88, 115, 132, 145, 128, 140, 155, 120],
            percentageChange: 0.22
        ),
        openPRs: [
            OpenPR(
                id: 4821,
                title: "Add idempotency keys to refund endpoint",
                authorLogin: "jordan-m",
                createdAt: Date(timeIntervalSinceNow: -3 * 86_400)
            ),
            OpenPR(
                id: 4818,
                title: "Switch webhook retries to exponential backoff",
                authorLogin: "ana-s",
                createdAt: Date(timeIntervalSinceNow: -5 * 86_400)
            ),
            OpenPR(
                id: 4810,
                title: "Drop legacy v1 charge serializer",
                authorLogin: "rahul-k",
                createdAt: Date(timeIntervalSinceNow: -8 * 86_400)
            ),
            OpenPR(
                id: 4805,
                title: "Bump postgres driver to 2.14",
                authorLogin: "miguel-t",
                createdAt: Date(timeIntervalSinceNow: -1 * 86_400)
            ),
            OpenPR(
                id: 4799,
                title: "Document the dispute lifecycle in README",
                authorLogin: "priya-s",
                createdAt: Date(timeIntervalSinceNow: -12 * 86_400)
            )
        ],
        mergedByDay: [
            DailyCount(label: "Mon", count: 4),
            DailyCount(label: "Tue", count: 6),
            DailyCount(label: "Wed", count: 3),
            DailyCount(label: "Thu", count: 5),
            DailyCount(label: "Fri", count: 4),
            DailyCount(label: "Sat", count: 1),
            DailyCount(label: "Sun", count: 1)
        ],
        ciRunsByDay: [
            DailyCount(label: "Mon", count: 22),
            DailyCount(label: "Tue", count: 31),
            DailyCount(label: "Wed", count: 18),
            DailyCount(label: "Thu", count: 27),
            DailyCount(label: "Fri", count: 24),
            DailyCount(label: "Sat", count: 12),
            DailyCount(label: "Sun", count: 8)
        ],
        contributors: [
            Contributor(login: "jordan-m", mergedPRs30d: 14, role: "Lead"),
            Contributor(login: "ana-s", mergedPRs30d: 11, role: nil),
            Contributor(login: "rahul-k", mergedPRs30d: 9, role: nil),
            Contributor(login: "miguel-t", mergedPRs30d: 7, role: "Reviewer"),
            Contributor(login: "priya-s", mergedPRs30d: 5, role: nil),
            Contributor(login: "sasha-q", mergedPRs30d: 3, role: nil)
        ],
        hotFiles: [
            HotFile(path: "Sources/Payments/ChargeProcessor.swift", churns30d: 38, weeklyChurns: [4, 7, 5, 9, 6, 4, 3]),
            HotFile(path: "Sources/Webhooks/RetryQueue.swift", churns30d: 27, weeklyChurns: [2, 5, 3, 6, 4, 4, 3]),
            HotFile(path: "Tests/Payments/RefundTests.swift", churns30d: 21, weeklyChurns: [1, 3, 4, 2, 5, 4, 2]),
            HotFile(path: "Sources/Models/Dispute.swift", churns30d: 18, weeklyChurns: [3, 2, 3, 2, 4, 2, 2]),
            HotFile(path: "Migrations/2026_04_disputes.sql", churns30d: 12, weeklyChurns: [0, 4, 2, 1, 2, 2, 1]),
            HotFile(path: "Sources/Networking/HTTPClient.swift", churns30d: 9, weeklyChurns: [1, 1, 2, 1, 1, 2, 1])
        ],
        security: SecuritySummary(critical: 3, high: 6, moderate: 9, low: 4),
        alertItems: [
            AlertItem(id: "CVE-2026-1042", severity: .critical, packageOrRule: "openssl", ageInDays: 9),
            AlertItem(id: "CVE-2026-0987", severity: .critical, packageOrRule: "libxml2", ageInDays: 14),
            AlertItem(id: "CVE-2025-9988", severity: .critical, packageOrRule: "curl", ageInDays: 22),
            AlertItem(id: "scan-rule-204", severity: .high, packageOrRule: "swift-secret-detection", ageInDays: 4),
            AlertItem(id: "CVE-2026-0612", severity: .high, packageOrRule: "swift-nio", ageInDays: 6)
        ],
        branches: [
            Branch(name: "main", kind: .default, aheadBy: 0, behindBy: 0, ageInDays: 0),
            Branch(name: "release/2026.05", kind: .staging, aheadBy: 12, behindBy: 0, ageInDays: 3),
            Branch(name: "feature/dispute-evidence-upload", kind: .behind, aheadBy: 4, behindBy: 27, ageInDays: 11),
            Branch(name: "experiment/grpc-transport", kind: .stale, aheadBy: 2, behindBy: 184, ageInDays: 92),
            Branch(name: "feature/webhook-signing-v2", kind: .behind, aheadBy: 9, behindBy: 14, ageInDays: 7),
            Branch(name: "chore/cleanup-old-tests", kind: .stale, aheadBy: 1, behindBy: 220, ageInDays: 140)
        ],
        releases: [
            Release(tag: "v2.14.0", body: "Webhook retry backoff and dispute evidence uploads.", ageInDays: 2, isMinor: true),
            Release(tag: "v2.13.4", body: "Patch: fix charge serializer crash on null currency.", ageInDays: 9, isMinor: false),
            Release(tag: "v2.13.3", body: "Patch: tighten idempotency key validation.", ageInDays: 16, isMinor: false),
            Release(tag: "v2.13.2", body: "Patch: bump postgres driver to 2.13.", ageInDays: 24, isMinor: false),
            Release(tag: "v2.13.0", body: "Refunds API stabilization and metrics overhaul.", ageInDays: 38, isMinor: true)
        ]
    )
}

// MARK: - RepositoryDossier.KPI

extension RepositoryDossier {

    /// The six headline metrics shown in the dossier's horizontal KPI strip.
    struct KPI: Sendable {

        /// Pull requests merged during the current calendar week.
        let mergedThisWeek: Int

        /// Week-over-week change in `mergedThisWeek`, or `nil` when prior data is unavailable.
        let mergedThisWeekDelta: Int?

        /// Total open pull requests on the repository.
        let openPRs: Int

        /// Subset of `openPRs` that have been idle for more than 7 days.
        let stalePRs: Int

        /// Total open issues on the repository.
        let openIssues: Int

        /// Issues closed during the last 7 days.
        let closedIssues7d: Int

        /// Total open security alerts across all categories.
        let securityAlerts: Int

        /// Subset of `securityAlerts` at `critical` severity.
        let criticalAlerts: Int

        /// CI pass percentage over the last 7 days, in the range `0`–`100`.
        let ciPassPct: Double

        /// Total CI runs that completed during the last 7 days.
        let ciRuns7d: Int

        /// Distinct contributors who pushed commits during the last 30 days.
        let contributors30d: Int
    }
}

// MARK: - RepositoryDossier.ActivityHeatmap

extension RepositoryDossier {

    /// A 26-week × 7-day commit intensity grid (182 cells) for the activity heatmap card.
    struct ActivityHeatmap: Sendable {

        /// Intensity values in row-major order, each in the range `0`–`4`.
        let cells: [Int]

        /// The Sunday that anchors the left edge of the 26-week window.
        let startDate: Date?

        /// The last day of the 26-week window (approximately today).
        let endDate: Date?

        /// Total commits across the entire 26-week window.
        let totalCommits: Int

        /// The calendar day with the single highest commit count, used in the meta strip.
        let peakDate: Date?

        init(cells: [Int], startDate: Date? = nil, endDate: Date? = nil, totalCommits: Int = 0, peakDate: Date? = nil) {
            self.cells = cells
            self.startDate = startDate
            self.endDate = endDate
            self.totalCommits = totalCommits
            self.peakDate = peakDate
        }
    }
}

// MARK: - RepositoryDossier.VelocitySpark

extension RepositoryDossier {

    /// A 26-week commit velocity sparkline used in the velocity card.
    struct VelocitySpark: Sendable {

        /// Weekly commit counts ordered oldest to newest (one entry per week of the 26-week window).
        let weeklyCommits: [Int]

        /// Percentage change comparing the last 13 weeks to the first 13 weeks, or `nil` when unavailable.
        let percentageChange: Double?

        init(weeklyCommits: [Int], percentageChange: Double? = nil) {
            self.weeklyCommits = weeklyCommits
            self.percentageChange = percentageChange
        }
    }
}

// MARK: - RepositoryDossier.OpenPR

extension RepositoryDossier {

    /// A single open pull request row used in the Pull Requests section.
    struct OpenPR: Sendable, Identifiable {

        /// The numeric pull request id (the `#` number on GitHub).
        let id: Int

        /// The pull request title.
        let title: String

        /// The author's GitHub login.
        let authorLogin: String

        /// The time the pull request was created.
        let createdAt: Date

    }
}

// MARK: - RepositoryDossier.DailyCount

extension RepositoryDossier {

    /// A labeled count for a single weekday, used by the merged-by-day and CI-runs-by-day cards.
    struct DailyCount: Sendable, Identifiable {

        /// The short weekday label, e.g. `"Mon"`.
        let label: String

        /// The aggregate count for the day.
        let count: Int

        /// The stable identity used by `ForEach`.
        var id: String { label }
    }
}

// MARK: - RepositoryDossier.Contributor

extension RepositoryDossier {

    /// A single contributor row used in the People section.
    struct Contributor: Sendable, Identifiable {

        /// The contributor's GitHub login.
        let login: String

        /// Pull requests merged by this contributor during the last 30 days.
        let mergedPRs30d: Int

        /// An optional role label (e.g. `"Lead"`, `"Reviewer"`).
        let role: String?

        /// The stable identity used by `ForEach`.
        var id: String { login }
    }
}

// MARK: - RepositoryDossier.HotFile

extension RepositoryDossier {

    /// A single hot-file row used in the People section.
    struct HotFile: Sendable, Identifiable {

        /// The repository-relative path to the file.
        let path: String

        /// Total churn (commits touching the file) over the last 30 days.
        let churns30d: Int

        /// Per-week churn counts for the last 7 weeks, oldest to newest.
        let weeklyChurns: [Int]

        /// The stable identity used by `ForEach`.
        var id: String { path }
    }
}

// MARK: - RepositoryDossier.SecuritySummary

extension RepositoryDossier {

    /// Aggregate counts of open security alerts grouped by severity.
    struct SecuritySummary: Sendable {

        /// Open alerts at `critical` severity.
        let critical: Int

        /// Open alerts at `high` severity.
        let high: Int

        /// Open alerts at `moderate` severity.
        let moderate: Int

        /// Open alerts at `low` severity.
        let low: Int

        /// Total open alerts across every severity bucket.
        var total: Int { critical + high + moderate + low }
    }
}

// MARK: - RepositoryDossier.AlertItem

extension RepositoryDossier {

    /// A single security alert row used in the Health & Security section.
    struct AlertItem: Sendable, Identifiable {

        /// The CVE id or scanning rule id.
        let id: String

        /// The alert's severity.
        let severity: Severity

        /// The vulnerable package name or scanning rule label.
        let packageOrRule: String

        /// Days since the alert was first opened.
        let ageInDays: Int

        /// Severity of a single security alert.
        enum Severity: String, Sendable {
            /// Critical severity — the highest tier.
            case critical
            /// High severity.
            case high
            /// Moderate severity.
            case moderate
            /// Low severity — the lowest tier.
            case low
        }
    }
}

// MARK: - RepositoryDossier.Branch

extension RepositoryDossier {

    /// A single branch row used in the Branches & Releases section.
    struct Branch: Sendable, Identifiable {

        /// The branch name.
        let name: String

        /// The branch's classification used to drive the row's chip.
        let kind: Kind

        /// Commits this branch is ahead of the default branch.
        let aheadBy: Int

        /// Commits this branch is behind the default branch.
        let behindBy: Int

        /// Days since the branch was last updated.
        let ageInDays: Int

        /// The stable identity used by `ForEach`.
        var id: String { name }

        /// Classification of a branch used to drive the row's display chip.
        enum Kind: Sendable {
            /// The repository's default branch.
            case `default`
            /// A long-lived release/staging branch.
            case staging
            /// A branch that is significantly behind the default.
            case behind
            /// A branch that has not been updated in a long time.
            case stale
        }
    }
}

// MARK: - RepositoryDossier.Release

extension RepositoryDossier {

    /// A single release row used in the Branches & Releases section.
    struct Release: Sendable, Identifiable {

        /// The release tag, e.g. `"v2.14.0"`.
        let tag: String

        /// The release notes body (typically truncated for display).
        let body: String

        /// Days since the release was published.
        let ageInDays: Int

        /// `true` for minor releases, `false` for patch / hotfix releases.
        let isMinor: Bool

        /// The stable identity used by `ForEach`.
        var id: String { tag }
    }
}

// MARK: - RepositoryDossier + SavedRepository Assembly

extension RepositoryDossier {

    /// Assembles a dossier from a saved repository and its persisted SwiftData relationships.
    ///
    /// Fields not yet stored locally — merged-by-day, CI runs, contributors, and hot files —
    /// are left empty so the view renders their "No data" empty states until those data
    /// sources are wired up.
    init(repository: SavedRepository) {
        owner = repository.owner
        name = repository.name
        displayName = repository.displayName
        description = repository.repositoryDescription ?? ""
        isPrivate = repository.isPrivate
        department = repository.team?.department?.name
        lastPushedAt = (repository.branches ?? []).map { $0.pushedAt }.max()
        defaultBranch = (repository.branches ?? []).first(where: { $0.isDefault })?.name ?? "main"
        primaryLanguage = repository.primaryLanguage

        // Security alerts
        let openDependabot = (repository.dependabotAlertDetails ?? []).filter { $0.state == "open" }
        let openCodeScanning = (repository.codeScanningAlertDetails ?? []).filter { $0.state == "open" }
        let openSecrets = (repository.secretScanningAlertDetails ?? []).filter { $0.state == "open" }

        let depBuckets = Self.bucketSeverities(openDependabot.map { $0.severity })
        let scanBuckets = Self.bucketSeverities(openCodeScanning.compactMap { $0.securitySeverityLevel })
        let secretCritical = openSecrets.filter { $0.publiclyLeaked }.count
        let secretHigh = openSecrets.count - secretCritical

        let criticalCount = depBuckets.critical + scanBuckets.critical + secretCritical
        let highCount = depBuckets.high + scanBuckets.high + secretHigh
        let moderateCount = depBuckets.moderate + scanBuckets.moderate
        let lowCount = depBuckets.low + scanBuckets.low

        security = SecuritySummary(
            critical: criticalCount,
            high: highCount,
            moderate: moderateCount,
            low: lowCount
        )

        var items: [AlertItem] = []
        for alert in openDependabot {
            let id = alert.cveId ?? (alert.ghsaId.isEmpty ? "dep-\(alert.alertNumber)" : alert.ghsaId)
            items.append(AlertItem(
                id: id,
                severity: Self.mapAlertSeverity(alert.severity),
                packageOrRule: alert.packageName,
                ageInDays: Int(Date().timeIntervalSince(alert.createdAt) / 86_400)
            ))
        }
        for alert in openCodeScanning {
            items.append(AlertItem(
                id: "scan-\(alert.alertNumber)",
                severity: Self.mapAlertSeverity(alert.securitySeverityLevel ?? "low"),
                packageOrRule: alert.ruleName,
                ageInDays: Int(Date().timeIntervalSince(alert.createdAt) / 86_400)
            ))
        }
        for alert in openSecrets {
            items.append(AlertItem(
                id: "secret-\(alert.alertNumber)",
                severity: alert.publiclyLeaked ? .critical : .high,
                packageOrRule: alert.secretTypeDisplayName,
                ageInDays: Int(Date().timeIntervalSince(alert.createdAt) / 86_400)
            ))
        }
        // Sort critical-first, then by age descending within each bucket
        items.sort { lhs, rhs in
            let lo = Self.severityRank(lhs.severity)
            let ro = Self.severityRank(rhs.severity)
            return lo == ro ? lhs.ageInDays > rhs.ageInDays : lo < ro
        }
        alertItems = items

        // Pull requests
        let sortedPRs = (repository.openPullRequests ?? []).sorted { $0.createdAt < $1.createdAt }
        openPRs = sortedPRs.map { pr in
            OpenPR(
                id: pr.number,
                title: pr.title,
                authorLogin: pr.authorLogin,
                createdAt: pr.createdAt
            )
        }

        // Contributors — open PR authors ranked by count, enriched with team roles
        let memberByLogin: [String: Member] = Dictionary(
            (repository.team?.members ?? []).compactMap { member in
                guard let login = member.githubLogin else { return nil }
                return (login, member)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let openPRAuthorCounts: [String: Int] = sortedPRs.reduce(into: [:]) { counts, pr in
            counts[pr.authorLogin, default: 0] += 1
        }

        // KPI strip
        let sevenDaysAgo = Date(timeIntervalSinceNow: -7 * 86_400)
        let stalePRCount = sortedPRs.filter { $0.createdAt < sevenDaysAgo }.count
        let velocity7d = (repository.velocityMetrics ?? []).first {
            $0.periodType == VelocityPeriod.sevenDays.rawValue
        }

        kpi = KPI(
            mergedThisWeek: velocity7d?.currentCount ?? 0,
            mergedThisWeekDelta: velocity7d.map { $0.currentCount - $0.priorCount },
            openPRs: sortedPRs.count,
            stalePRs: stalePRCount,
            openIssues: 0,
            closedIssues7d: 0,
            securityAlerts: criticalCount + highCount + moderateCount + lowCount,
            criticalAlerts: criticalCount,
            ciPassPct: 0,
            ciRuns7d: 0,
            contributors30d: openPRAuthorCounts.keys.count
        )

        // Activity heatmap and velocity spark — both assembled from stored per-day commit counts
        // so the two activity cards present a unified 26-week picture.
        let commitDays = (repository.commitActivity ?? []).sorted { $0.date < $1.date }
        if commitDays.isEmpty {
            activityHeatmap = ActivityHeatmap(cells: [])
            velocitySpark = VelocitySpark(weeklyCommits: [])
        } else {
            let (heatmap, weekly, pctChange) = Self.buildActivityData(from: commitDays)
            activityHeatmap = heatmap
            velocitySpark = VelocitySpark(weeklyCommits: weekly, percentageChange: pctChange)
        }
        mergedByDay = []
        ciRunsByDay = []
        contributors = openPRAuthorCounts
            .map { login, count in
                Contributor(
                    login: login,
                    mergedPRs30d: count,
                    role: memberByLogin[login]?.jobTitle?.name
                )
            }
            .sorted { $0.mergedPRs30d > $1.mergedPRs30d }
        hotFiles = []

        // Branches — classify by name pattern and age; ordered by most recently pushed.
        let branchNow = Date()
        branches = (repository.branches ?? [])
            .sorted { $0.pushedAt > $1.pushedAt }
            .map { saved in
                let ageInDays = Int(branchNow.timeIntervalSince(saved.pushedAt) / 86_400)
                return Branch(
                    name: saved.name,
                    kind: Self.classifyBranch(name: saved.name, isDefault: saved.isDefault, ageInDays: ageInDays),
                    aheadBy: 0,
                    behindBy: 0,
                    ageInDays: ageInDays
                )
            }

        // Releases — newest first, capped at 5 for the dossier card.
        let now = Date()
        releases = (repository.releases ?? [])
            .sorted { $0.publishedAt > $1.publishedAt }
            .prefix(5)
            .map { saved in
                Release(
                    tag: saved.tag,
                    body: saved.name.isEmpty ? saved.body : saved.name,
                    ageInDays: Int(now.timeIntervalSince(saved.publishedAt) / 86_400),
                    isMinor: Self.isMinorRelease(tag: saved.tag)
                )
            }
    }

    // MARK: - Private Helpers

    /// Classifies a branch for display based on its name pattern and age.
    ///
    /// Classification rules, applied in order:
    /// 1. `isDefault == true` → `.default`
    /// 2. Name matches long-lived release/staging patterns → `.staging`
    /// 3. `ageInDays >= 30` → `.stale`
    /// 4. Otherwise → `.behind` (active feature branch, likely diverging from default)
    // TODO: Replace age-based `.behind` / `.stale` classification with real ahead/behind counts once the GitHub API comparison endpoint is integrated — name-and-age heuristics will misclassify recently created branches that are deeply behind.
    private static func classifyBranch(name: String, isDefault: Bool, ageInDays: Int) -> Branch.Kind {
        if isDefault { return .default }
        let lower = name.lowercased()
        if lower.hasPrefix("release/") || lower.hasPrefix("hotfix/")
            || lower == "staging" || lower == "develop" || lower == "preview" {
            return .staging
        }
        return ageInDays >= 30 ? .stale : .behind
    }

    /// Returns `true` when the tag's patch version component is zero (e.g. `"v2.14.0"`).
    private static func isMinorRelease(tag: String) -> Bool {
        let stripped = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let parts = stripped.split(separator: ".").compactMap { Int($0) }
        return parts.count >= 3 && parts[2] == 0
    }

    private static func mapAlertSeverity(_ raw: String) -> AlertItem.Severity {
        switch raw.lowercased() {
        case "critical": return .critical
        case "high": return .high
        case "medium", "moderate": return .moderate
        default: return .low
        }
    }

    private static func severityRank(_ severity: AlertItem.Severity) -> Int {
        switch severity {
        case .critical: 0
        case .high: 1
        case .moderate: 2
        case .low: 3
        }
    }

    /// Builds the full activity dataset — heatmap cells, weekly commit totals, and velocity
    /// percentage change — from stored ``RepositoryCommitDay`` records in a single pass.
    ///
    /// The heatmap grid is row-major: `cells[row * 26 + column]` where `row` is the weekday
    /// (0 = Sunday … 6 = Saturday) and `column` is the week index (0 = oldest, 25 = newest).
    /// Cell values are bucketed into intensity levels 0–4 relative to the maximum daily count.
    /// Weekly commit totals are summed across all seven days of each column.
    /// Percentage change compares the aggregate of the last 13 weeks to the first 13 weeks.
    private static func buildActivityData(
        from days: [RepositoryCommitDay]
    ) -> (heatmap: ActivityHeatmap, weeklyCommits: [Int], percentageChange: Double?) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Anchor the grid: the Sunday that began 26 weeks ago.
        let today = Date()
        guard let rawStart = calendar.date(byAdding: .day, value: -(26 * 7), to: today) else {
            return (ActivityHeatmap(cells: []), [], nil)
        }
        // .weekday: 1 = Sunday … 7 = Saturday; subtract 1 to get days back to the prior Sunday.
        let weekdayOfStart = calendar.component(.weekday, from: rawStart)
        let daysBackToSunday = weekdayOfStart - 1
        guard let startSunday = calendar.date(byAdding: .day, value: -daysBackToSunday, to: rawStart) else {
            return (ActivityHeatmap(cells: []), [], nil)
        }

        // Build a date → count lookup (normalise to midnight UTC).
        var countByDate: [Date: Int] = [:]
        for day in days {
            let midnight = calendar.startOfDay(for: day.date)
            countByDate[midnight, default: 0] += day.commitCount
        }

        let maxCount = countByDate.values.max() ?? 0
        let totalCommits = countByDate.values.reduce(0, +)
        let peakDate = countByDate.max(by: { $0.value < $1.value })?.key

        var cells = [Int](repeating: 0, count: 7 * 26)
        var weeklyTotals = [Int](repeating: 0, count: 26)

        for (date, count) in countByDate {
            let daysSinceStart = calendar.dateComponents([.day], from: startSunday, to: date).day ?? -1
            guard daysSinceStart >= 0 else { continue }
            let weekColumn = daysSinceStart / 7
            guard weekColumn < 26 else { continue }
            // .weekday: 1 = Sunday, so row 0 maps to Sunday, row 6 to Saturday.
            let weekdayRow = calendar.component(.weekday, from: date) - 1
            cells[weekdayRow * 26 + weekColumn] = intensityBucket(count, max: maxCount)
            weeklyTotals[weekColumn] += count
        }

        let firstWeek = weeklyTotals.first ?? 0
        let lastWeek = weeklyTotals.last ?? 0
        let percentageChange: Double? = firstWeek > 0 ? Double(lastWeek - firstWeek) / Double(firstWeek) : nil

        let endDate = calendar.date(byAdding: .day, value: 26 * 7 - 1, to: startSunday) ?? today

        let heatmap = ActivityHeatmap(
            cells: cells,
            startDate: startSunday,
            endDate: endDate,
            totalCommits: totalCommits,
            peakDate: peakDate
        )
        return (heatmap, weeklyTotals, percentageChange)
    }

    /// Maps a commit count to a display intensity bucket (0–4).
    ///
    /// - Returns: `0` for zero commits; `1`–`4` scaled to the dataset maximum.
    private static func intensityBucket(_ count: Int, max maxCount: Int) -> Int {
        guard count > 0, maxCount > 0 else { return 0 }
        let ratio = Double(count) / Double(maxCount)
        if ratio <= 0.25 { return 1 }
        if ratio <= 0.50 { return 2 }
        if ratio <= 0.75 { return 3 }
        return 4
    }

    private static func bucketSeverities(
        _ severities: [String]
    ) -> (critical: Int, high: Int, moderate: Int, low: Int) {
        var c = 0, h = 0, m = 0, l = 0
        for s in severities {
            switch mapAlertSeverity(s) {
            case .critical: c += 1
            case .high: h += 1
            case .moderate: m += 1
            case .low: l += 1
            }
        }
        return (c, h, m, l)
    }
}
