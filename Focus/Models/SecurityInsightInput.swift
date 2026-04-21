import Foundation

// MARK: - SecurityInsightKind

/// A discriminated union identifying exactly which security rule fired.
///
/// The kind carries the concrete data points used to render the insight. Tests
/// and the aggregator use this to reason about insights without parsing title
/// strings.
enum SecurityInsightKind: Sendable, Hashable {

    // MARK: P0 — Immediate

    /// An active, publicly-leaked secret was detected.
    case publiclyLeakedSecret(secretType: String, repoName: String)

    /// Push protection was bypassed to commit a secret.
    case pushProtectionBypassed(repoName: String)

    // MARK: P1 — Urgent

    /// CVSS ≥ threshold alerts have been open beyond the age limit.
    case highCvssUnchecked(count: Int, maxCvss: Double, oldestDays: Int)

    /// A critical vulnerability is spread across multiple repos and aging.
    case multiRepoCriticalSpread(repos: [String], ageDays: Int)

    /// Unassigned critical alerts are aging beyond the threshold.
    case agingUnassignedCriticals(count: Int, oldestDays: Int)

    /// Fallback P1: a repo has open critical alerts. (Legacy behavior.)
    case criticalAlertsInRepo(repoName: String, count: Int)

    // MARK: P2 — Notable

    /// The same secret type is exposed across multiple repos.
    case multiRepoSecret(secretType: String, repoCount: Int)

    /// One advisory affects many repos (shared blast radius).
    case sharedBlastRadius(packageName: String, repoCount: Int, ghsaId: String)

    /// One ecosystem dominates the open Dependabot backlog.
    case ecosystemConcentration(ecosystem: String, count: Int, totalOpen: Int)

    /// A repo has breached the configured SLA threshold for criticals.
    case slaBreach(repoName: String, ageDays: Int, thresholdDays: Int)

    /// Many Code Scanning alerts trace back to the same rule.
    case codeScanningRulePattern(ruleId: String, ruleName: String, count: Int, total: Int)

    /// Open alert count has grown for N consecutive weeks. (Tier 2.)
    case alertDebtTrend(weeks: Int, delta: Int)

    /// A repo that was clean last week now has critical alerts. (Tier 2.)
    case newRepoAtRisk(repoName: String)

    // MARK: P3 — Positive

    /// The critical backlog was cleared or reduced week-over-week. (Tier 2 — needs snapshot.)
    case criticalBacklogCleared(clearedCount: Int)

    /// A previously-noisy repo is now clean. (Tier 2.)
    case repoWentClean(repoName: String)

    /// Upgrades are available for a meaningful share of critical alerts.
    case fixesAvailable(count: Int, criticalCount: Int)

    /// The total open-alert count dropped week-over-week. (Tier 2.)
    case alertCountDropped(delta: Int, fromTotal: Int)

    /// N consecutive clean weeks. (Tier 2.)
    case cleanStreak(weeks: Int)

    /// Closures outpaced intake this week. (Tier 3 — needs closure API.)
    case closureVelocityBeatIntake(closed: Int, opened: Int)

    // MARK: P4 — Informational

    /// The repo that closed the most alerts this week. (Tier 3.)
    case fastestResolvingRepo(repoName: String, closedCount: Int)

    /// Intake is accelerating relative to closures. (Tier 3.)
    case intakeAccelerating(opened: Int, closed: Int)
}

// MARK: - DependabotAlertSummary

/// A cheap `Sendable` projection of ``DependabotAlert`` for use inside rule evaluation.
///
/// Rules run off value types so they can be unit tested without SwiftData and executed
/// off the main actor if needed.
struct DependabotAlertSummary: Sendable {

    /// The owning repository's display name.
    let repoName: String

    /// Severity string — `"critical"` / `"high"` / `"medium"` / `"low"`.
    let severity: String

    /// Package ecosystem (e.g. `"npm"`, `"pip"`).
    let ecosystem: String

    /// Affected package name.
    let packageName: String

    /// GitHub Security Advisory ID, used to group blast-radius insights.
    let ghsaId: String

    /// CVSS numeric score, or `nil` if the advisory didn't report one.
    let cvssScore: Double?

    /// Whole days between the alert's `createdAt` and the week-end reference date.
    let ageInDays: Int

    /// Whether any user is assigned to remediate this alert.
    let hasAssignee: Bool

    /// Whether the advisory reports a fix version.
    let fixAvailable: Bool
}

// MARK: - CodeScanningAlertSummary

/// A cheap `Sendable` projection of ``CodeScanningAlert``.
struct CodeScanningAlertSummary: Sendable {

    /// The owning repository's display name.
    let repoName: String

    /// Stable rule identifier (e.g. `"js/sql-injection"`), or `nil` if not reported.
    let ruleId: String?

    /// Human-readable rule name.
    let ruleName: String

    /// Optional severity string as reported by GitHub.
    let severity: String?

    /// Whole days between `createdAt` and the week-end reference date.
    let ageInDays: Int
}

// MARK: - SecretAlertSummary

/// A cheap `Sendable` projection of ``SecretScanningAlert``.
struct SecretAlertSummary: Sendable {

    /// The owning repository's display name.
    let repoName: String

    /// Human-readable secret-type name (e.g. `"GitHub Personal Access Token"`).
    let secretTypeDisplayName: String

    /// Validity state — `"active"` / `"revoked"` / `"unknown"`.
    let validity: String

    /// Whether GitHub reports the secret as publicly leaked.
    let publiclyLeaked: Bool

    /// Whether push protection was bypassed when committing the secret.
    let pushProtectionBypassed: Bool

    /// Whether this secret was detected across multiple repos.
    let multiRepo: Bool
}

// MARK: - SecurityRepoDetail

/// Per-repo counts used by rules that need repo-level rollups.
struct SecurityRepoDetail: Sendable {

    /// The repository display name.
    let repoName: String

    /// Total open alerts across all scanners.
    let openAlerts: Int

    /// Number of open critical alerts.
    let criticalCount: Int

    /// Age in days of the oldest open critical alert, or `nil` if none.
    let oldestCriticalAgeInDays: Int?
}

// MARK: - SecurityWeekTotals

/// Per-week totals used by Tier 2 historical trend rules.
///
/// Populated from the forthcoming `SecurityWeeklySnapshot` persistence layer.
/// Until snapshots land, callers pass `nil`/empty history and trend rules no-op.
struct SecurityWeekTotals: Sendable {

    /// Start of the week (Monday in the user's calendar).
    let weekStart: Date

    /// Total open alerts at week end.
    let totalOpen: Int

    /// Total open critical alerts at week end.
    let totalCritical: Int

    /// Alerts created during the week.
    let opened: Int

    /// Alerts dismissed or fixed during the week. `0` until Tier 3 closure API fetch ships.
    let closed: Int

    /// Per-repo critical counts at week end, keyed by repo display name.
    let repoCriticalCounts: [String: Int]

    /// Dependabot alerts dismissed or fixed during the week, keyed by repo display name.
    /// Empty until Tier 3 closure API fetch ships.
    let repoClosedCounts: [String: Int]
}

// MARK: - SecurityInsightInput

/// The full input snapshot passed to ``SecurityInsightGenerator``.
///
/// All fields are `Sendable` value types so generation can run off the main actor
/// and be exercised by deterministic unit tests.
struct SecurityInsightInput: Sendable {

    /// The week interval the briefing covers.
    let weekInterval: DateInterval

    /// All open Dependabot alerts (not just criticals).
    let dependabotSummaries: [DependabotAlertSummary]

    /// All open code scanning alerts.
    let codeScanningAlerts: [CodeScanningAlertSummary]

    /// All open secret scanning alerts.
    let secretAlerts: [SecretAlertSummary]

    /// Per-repo rollups.
    let repoDetails: [SecurityRepoDetail]

    /// Totals for the week being reported. `nil` until Tier 2 snapshots ship.
    let currentWeekTotals: SecurityWeekTotals?

    /// Totals for the prior week. `nil` until Tier 2 snapshots ship.
    let priorWeekTotals: SecurityWeekTotals?

    /// Up to 8 weeks of history, oldest first. Empty until Tier 2 snapshots ship.
    let weekHistory: [SecurityWeekTotals]
}
