import Foundation

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

    /// The repository's short description as it appears on GitHub.
    let description: String

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
        description: "Core payments service handling charges, refunds, and webhook delivery.",
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
            }
        ),
        velocitySpark: VelocitySpark(
            weeklyMerged: [12, 18, 14, 22, 9, 17, 25, 21, 19, 28, 24, 16, 22, 27, 30, 24]
        ),
        openPRs: [
            OpenPR(
                id: 4821,
                title: "Add idempotency keys to refund endpoint",
                authorLogin: "jordan-m",
                createdAt: Date(timeIntervalSinceNow: -3 * 86_400),
                ciStatus: .passing
            ),
            OpenPR(
                id: 4818,
                title: "Switch webhook retries to exponential backoff",
                authorLogin: "ana-s",
                createdAt: Date(timeIntervalSinceNow: -5 * 86_400),
                ciStatus: .failing
            ),
            OpenPR(
                id: 4810,
                title: "Drop legacy v1 charge serializer",
                authorLogin: "rahul-k",
                createdAt: Date(timeIntervalSinceNow: -8 * 86_400),
                ciStatus: .passing
            ),
            OpenPR(
                id: 4805,
                title: "Bump postgres driver to 2.14",
                authorLogin: "miguel-t",
                createdAt: Date(timeIntervalSinceNow: -1 * 86_400),
                ciStatus: .none
            ),
            OpenPR(
                id: 4799,
                title: "Document the dispute lifecycle in README",
                authorLogin: "priya-s",
                createdAt: Date(timeIntervalSinceNow: -12 * 86_400),
                ciStatus: .passing
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
    }
}

// MARK: - RepositoryDossier.VelocitySpark

extension RepositoryDossier {

    /// A 16-week merged-PR sparkline used in the velocity card.
    struct VelocitySpark: Sendable {

        /// Weekly merged PR counts ordered oldest to newest.
        let weeklyMerged: [Int]
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

        /// The current CI check status for the pull request.
        let ciStatus: CIStatus

        /// CI check status for an open pull request.
        enum CIStatus: Sendable {
            /// All required checks are passing.
            case passing
            /// At least one required check is failing.
            case failing
            /// No checks have reported (or none are configured).
            case none
        }
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
