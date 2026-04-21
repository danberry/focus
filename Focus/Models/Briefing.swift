import Foundation

// MARK: - Briefing

/// A computed snapshot of engineering activity for the previous calendar week.
///
/// `Briefing` is a pure value type assembled by ``BriefingService`` at display time.
/// It is not persisted to SwiftData — instead it reads fresh GraphQL counts and the
/// existing local SwiftData graph to produce a single immutable dashboard payload.
struct Briefing: Sendable {

    // MARK: - Properties

    /// The time at which this briefing was assembled.
    let generatedAt: Date

    /// The ISO week-of-year number that this briefing covers.
    let volume: Int

    /// Human-readable range of the covered week, e.g. `"Apr 13 — 18, 2026"`.
    let weekRange: String

    /// The hero verdict pair shown at the top of the briefing.
    let hero: BriefingHero

    /// The three ranked attention items. Always contains exactly three elements.
    let attention: [BriefingAttentionItem]

    /// The KPI strip totals for the week.
    let kpis: BriefingKPIs

    /// "What Shipped" section data.
    let shipped: BriefingShipped

    /// "Who Looks Blocked" section data.
    let blocked: BriefingBlocked

    /// "Security Debt" section data.
    let security: BriefingSecurity

    /// Per-repository security health rows shown at the bottom of the briefing.
    let repoHealth: [BriefingRepoHealth]

    // MARK: - Placeholder

    /// A hardcoded placeholder used by SwiftUI previews and empty-data fallbacks.
    ///
    /// Values are chosen to be realistic against the design mock rather than synthesized
    /// from live data.
    static let placeholder: Briefing = Briefing(
        generatedAt: Date(),
        volume: 16,
        weekRange: "Apr 13 — 18, 2026",
        hero: BriefingHero(
            verdictA: "Shipping OK.",
            verdictB: "Security is the story.",
            highlightWord: "Security",
            highlight: .red
        ),
        attention: [
            BriefingAttentionItem(
                n: "01",
                tone: .red,
                title: "12 critical alerts open in `payments-api`.",
                meta: "No triage in 9 days · escalate to @security",
                actionLabel: "Open alerts →",
                insight: nil
            ),
            BriefingAttentionItem(
                n: "02",
                tone: .blue,
                title: "Priya Shah idle 6 days.",
                meta: "Last commit: Apr 12 · Platform team",
                actionLabel: "DM Priya →",
                insight: nil
            ),
            BriefingAttentionItem(
                n: "03",
                tone: .neutral,
                title: "Only 4 PRs merged in `mobile-ios`.",
                meta: "Down from 11 the prior week",
                actionLabel: "See repo →",
                insight: nil
            )
        ],
        kpis: BriefingKPIs(
            shipping: BriefingKPIShipping(
                value: 73,
                dailyCounts: [8, 12, 9, 15, 11, 14, 4],
                priorWeekValue: 62
            ),
            security: BriefingKPISecurity(
                value: 48,
                critical: 12,
                dailyOpenTotals: [38, 41, 43, 45, 46, 47, 48],
                priorWeekTotal: 38
            ),
            idle: BriefingKPIIdle(value: 2, delta: 1),
            medianMerge: BriefingKPIMedianMerge(value: 18, dailyMedians: [22, 14, 18, 31, 12, 20, 16], priorWeekValue: 24),
            ciPass: nil,
            releases: nil,
            prSize: nil,
            activeContributors: BriefingKPIActiveContributors(value: 28, totalTracked: 34, priorWeekValue: 25),
            mergeRate: BriefingKPIMergeRate(value: 87, merged: 73, opened: 84, priorWeekValue: 79),
            stalePRCount: BriefingKPIStalePRCount(value: 5, oldestAgeDays: 23, priorWeekValue: 4),
            timeToFirstReview: BriefingKPITimeToFirstReview(value: 6, dailyMedians: [8, 5, 6, 9, 4, 7, 6], priorWeekValue: 10),
            unreviewedMergeRate: BriefingKPIUnreviewedMergeRate(value: 12, unreviewed: 9, total: 73, priorWeekValue: 8)
        ),
        shipped: BriefingShipped(
            verdict: "`payments-api` led the week with 24 merges.",
            summary: "The top repo represents 33% of all merged PRs this week · 0 repos with no PRs",
            repos: [
                BriefingRepoCount(name: "payments-api", count: 24, flag: true),
                BriefingRepoCount(name: "web-app", count: 18, flag: false),
                BriefingRepoCount(name: "mobile-ios", count: 14, flag: false),
                BriefingRepoCount(name: "infra", count: 11, flag: false),
                BriefingRepoCount(name: "design-system", count: 6, flag: false)
            ],
            contributors: [
                BriefingContributor(initials: "JM", name: "Jordan Miles", githubLogin: nil, count: 14),
                BriefingContributor(initials: "AS", name: "Ana Silva", githubLogin: nil, count: 11),
                BriefingContributor(initials: "RK", name: "Rahul Kumar", githubLogin: nil, count: 9)
            ]
        ),
        blocked: BriefingBlocked(
            verdict: "2 members went quiet this week.",
            summary: "Heuristic: no commits this week · 2 of 34 people flagged",
            members: [
                BriefingBlockedMember(
                    initials: "PS",
                    name: "Priya Shah",
                    team: "Platform",
                    idleLabel: "6d",
                    recommendation: "Usually ships 4+ PRs / week. Check in.",
                    urgent: true,
                    neverContributed: false,
                    githubLogin: "priyashah"
                ),
                BriefingBlockedMember(
                    initials: "MT",
                    name: "Miguel Torres",
                    team: "Payments",
                    idleLabel: "4d",
                    recommendation: "Blocked on review for 3 open PRs.",
                    urgent: false,
                    neverContributed: false,
                    githubLogin: "mtorres"
                )
            ]
        ),
        security: BriefingSecurity(
            verdict: "Dependabot debt grew again.",
            buckets: [
                BriefingSecurityBucket(name: "Dependabot", open: 34, delta: 3, critical: 12),
                BriefingSecurityBucket(name: "Code Scanning", open: 11, delta: 0, critical: 0),
                BriefingSecurityBucket(name: "Secrets", open: 3, delta: -1, critical: 0)
            ]
        ),
        repoHealth: [
            BriefingRepoHealth(name: "payments-api", openAlerts: 22, score: 38, urgent: true),
            BriefingRepoHealth(name: "web-app", openAlerts: 14, score: 55, urgent: false),
            BriefingRepoHealth(name: "mobile-ios", openAlerts: 8, score: 70, urgent: false),
            BriefingRepoHealth(name: "infra", openAlerts: 3, score: 85, urgent: false),
            BriefingRepoHealth(name: "design-system", openAlerts: 1, score: 95, urgent: false)
        ]
    )
}

// MARK: - BriefingHero

/// The two-part hero verdict shown at the top of the briefing, with an optional highlight word.
struct BriefingHero: Sendable {

    /// The first verdict fragment, e.g. `"Shipping OK."`.
    let verdictA: String

    /// The second verdict fragment, e.g. `"Security is the story."`.
    let verdictB: String

    /// The word within `verdictB` that receives a tone-matched highlight band.
    let highlightWord: String

    /// The tone used for the highlight band behind `highlightWord`.
    let highlight: BriefingTone
}

// MARK: - BriefingAttentionItem

/// One ranked attention card shown beneath the hero verdict.
struct BriefingAttentionItem: Sendable, Equatable, Hashable {

    /// The section number chip, e.g. `"01"`.
    let n: String

    /// The semantic tone that drives card fill, border, and chip colors.
    let tone: BriefingTone

    /// The primary title sentence.
    let title: String

    /// The supporting meta line.
    let meta: String

    /// The label of the full-width action button.
    let actionLabel: String

    /// The underlying engine-generated insight, or `nil` for hardcoded/fallback cards.
    ///
    /// Populated when the attention item was produced by a domain generator
    /// (e.g. ``SecurityInsightGenerator``). Views can read this to get richer
    /// context (domain, priority, rule kind) than the display strings expose.
    let insight: BriefingInsight?
}

// MARK: - BriefingKPIs

/// The KPI strip shown between the hero and the first section.
struct BriefingKPIs: Sendable {

    /// Merged PR totals and sparkline.
    let shipping: BriefingKPIShipping

    /// Open security alert totals and sparkline.
    let security: BriefingKPISecurity

    /// Idle-member totals and delta vs. the prior week.
    let idle: BriefingKPIIdle

    /// Median time from PR open to merge, or `nil` if not tracked.
    let medianMerge: BriefingKPIMedianMerge?

    /// CI pass rate for the current and prior week, or `nil` if no PRs had checks.
    let ciPass: BriefingKPICIPass?

    /// GitHub release count across all tracked repos in the last 7 days, or `nil` if not tracked.
    let releases: BriefingKPIReleases?

    /// Median PR size (lines changed) for the week, or `nil` if no PRs were merged.
    let prSize: BriefingKPIPRSize?

    /// Active contributor count: tracked members with at least one contribution this week.
    let activeContributors: BriefingKPIActiveContributors?

    /// Merge rate: percentage of PRs opened this week that were merged this week, or `nil` if not tracked.
    let mergeRate: BriefingKPIMergeRate?

    /// Stale PR count: open PRs older than the stale threshold, or `nil` if no PRs are tracked.
    let stalePRCount: BriefingKPIStalePRCount?

    /// Median time from PR open to first review submission, or `nil` if no PRs received a review this week.
    let timeToFirstReview: BriefingKPITimeToFirstReview?

    /// Unreviewed merge rate: percentage of merged PRs that received no review before merging, or `nil` if no PRs were merged.
    let unreviewedMergeRate: BriefingKPIUnreviewedMergeRate?
}

// MARK: - BriefingKPIShipping

/// Shipping KPI (merged PR total + 7-day bar chart).
struct BriefingKPIShipping: Sendable {

    /// Total merged pull requests for the week across all tracked repos.
    let value: Int

    /// Raw PR counts per day for the 7-day report period, ordered oldest to newest.
    let dailyCounts: [Int]

    /// Total merged PRs for the prior week, used to compute week-over-week delta.
    let priorWeekValue: Int?
}

// MARK: - BriefingKPISecurity

/// Security KPI (open alert total, critical count, and 7-day open-total sparkline).
struct BriefingKPISecurity: Sendable {

    /// Total open security alerts across all tracked repos.
    let value: Int

    /// The number of alerts at `"critical"` severity.
    let critical: Int

    /// Total open alert count per day for the 7-day report period, ordered oldest to newest.
    let dailyOpenTotals: [Int]

    /// Total open alerts at the end of the prior week, used to compute week-over-week delta.
    let priorWeekTotal: Int?
}

// MARK: - BriefingKPIIdle

/// Idle KPI (count of members with zero activity + week-over-week delta).
struct BriefingKPIIdle: Sendable {

    /// The number of tracked members with zero contributions this week.
    let value: Int

    /// Change relative to the prior week (positive = more idle members now).
    let delta: Int
}

// MARK: - BriefingKPICIPass

/// CI pass rate KPI (percentage of merged PRs whose CI checks all passed).
struct BriefingKPICIPass: Sendable {

    /// Percentage of merged PRs with all checks passing this week (0–100).
    let value: Int

    /// Same percentage for the prior week, used to compute week-over-week delta.
    let priorWeekValue: Int?
}

// MARK: - BriefingKPIMedianMerge

/// Cycle time KPI (median hours from PR open to merge, with a 7-day sparkline).
struct BriefingKPIMedianMerge: Sendable {

    /// Median hours from PR open to merge this week.
    let value: Int

    /// Median cycle-time hours per day for the 7-day report period, ordered oldest to newest.
    let dailyMedians: [Int]

    /// Same metric for the prior week, used to compute week-over-week delta.
    let priorWeekValue: Int?
}

// MARK: - BriefingKPIReleases

/// Releases KPI (GitHub release count for the week + prior-week comparison).
struct BriefingKPIReleases: Sendable {

    /// Total GitHub releases published this week across all tracked repos.
    let value: Int

    /// Same count for the prior week, used to compute week-over-week delta.
    let priorWeekValue: Int?
}

// MARK: - BriefingKPIPRSize

/// PR size KPI (median lines changed per merged PR for the week + 7-day sparkline).
struct BriefingKPIPRSize: Sendable {

    /// Median lines changed (additions + deletions) per merged PR for the week.
    let value: Int

    /// Median lines changed per PR per day for the 7-day report period, ordered oldest to newest.
    let dailyMedians: [Int]

    /// Same metric for the prior week, used to compute week-over-week delta.
    let priorWeekValue: Int?
}

// MARK: - BriefingKPIActiveContributors

/// Active Contributors KPI (count of tracked members with at least one contribution this week).
struct BriefingKPIActiveContributors: Sendable {

    /// Members with at least one contribution this week.
    let value: Int

    /// Total number of tracked members (denominator for the activity rate).
    let totalTracked: Int

    /// Same active count for the prior week, used to compute week-over-week delta.
    let priorWeekValue: Int?
}

// MARK: - BriefingKPIMergeRate

/// Merge rate KPI (ratio of merged PRs to opened PRs for the week).
struct BriefingKPIMergeRate: Sendable {

    /// Percentage of PRs merged vs. opened this week (0–100+; can exceed 100 when clearing backlog).
    let value: Int

    /// Total PRs merged during the week.
    let merged: Int

    /// Total PRs opened (created) during the week.
    let opened: Int

    /// Same percentage for the prior week, used to compute week-over-week delta.
    let priorWeekValue: Int?
}

// MARK: - BriefingKPIStalePRCount

/// Stale PR Count KPI (open pull requests older than the stale threshold).
struct BriefingKPIStalePRCount: Sendable {

    /// Count of open PRs that have been open longer than the stale threshold.
    let value: Int

    /// Age in days of the oldest stale PR, or `nil` if there are no stale PRs.
    let oldestAgeDays: Int?

    /// Stale PR count at the prior week end, used to compute week-over-week delta.
    let priorWeekValue: Int?
}

// MARK: - BriefingKPITimeToFirstReview

/// Time to First Review KPI (median hours from PR open to first review, with a 7-day sparkline).
struct BriefingKPITimeToFirstReview: Sendable {

    /// Median hours from PR open to first review submission this week.
    let value: Int

    /// Median time-to-first-review hours per day for the 7-day report period, ordered oldest to newest.
    let dailyMedians: [Int]

    /// Same metric for the prior week, used to compute week-over-week delta.
    let priorWeekValue: Int?
}

// MARK: - BriefingKPIUnreviewedMergeRate

/// Unreviewed Merge Rate KPI (percentage of merged PRs that had no review before merging).
struct BriefingKPIUnreviewedMergeRate: Sendable {

    /// Percentage of merged PRs that had no review (0–100).
    let value: Int

    /// Count of PRs merged without any review this week.
    let unreviewed: Int

    /// Total PRs merged this week (denominator).
    let total: Int

    /// Same percentage for the prior week, used to compute week-over-week delta.
    let priorWeekValue: Int?
}

// MARK: - BriefingShipped

/// "What Shipped" section payload.
struct BriefingShipped: Sendable {

    /// The editorial verdict shown under the section header.
    let verdict: String

    /// Supporting summary line shown beneath the verdict (e.g. "73 PRs across 5 repos — 3 contributors").
    let summary: String

    /// Per-repo merged PR counts, ordered with the leading repo first.
    let repos: [BriefingRepoCount]

    /// Top contributors for the week, ordered with the highest count first.
    let contributors: [BriefingContributor]
}

// MARK: - BriefingRepoCount

/// A per-repo count row used inside ``BriefingShipped``.
struct BriefingRepoCount: Sendable {

    /// The repository display name.
    let name: String

    /// The merged PR count for the week.
    let count: Int

    /// When `true`, the row is rendered with the leading-repo accent.
    let flag: Bool
}

// MARK: - BriefingContributor

/// A per-member contribution row used inside ``BriefingShipped``.
struct BriefingContributor: Sendable {

    /// Avatar initials shown in the leading circle.
    let initials: String

    /// The member's display name.
    let name: String

    /// The GitHub login used to load the member's avatar; `nil` falls back to initials.
    let githubLogin: String?

    /// The contribution count for the week.
    let count: Int
}

// MARK: - BriefingBlocked

/// "Who Looks Blocked" section payload.
struct BriefingBlocked: Sendable {

    /// The editorial verdict shown under the section header.
    let verdict: String

    /// A one-line heuristic description and flagged-vs-total count shown beneath the verdict.
    let summary: String

    /// The list of idle or blocked members.
    let members: [BriefingBlockedMember]
}

// MARK: - BriefingBlockedMember

/// A single blocked-member row used inside ``BriefingBlocked``.
struct BriefingBlockedMember: Sendable {

    /// Avatar initials shown in the leading circle.
    let initials: String

    /// The member's display name.
    let name: String

    /// The member's team label.
    let team: String

    /// A compact idle duration label, e.g. `"6d"`.
    let idleLabel: String

    /// A short italic recommendation shown beneath the name.
    let recommendation: String

    /// When `true`, the row is rendered with the urgent (blue) tone.
    let urgent: Bool

    /// When `true`, the member has no contribution history at all — rendered with the red tone.
    let neverContributed: Bool

    /// The member's GitHub login, or `nil` if not linked.
    let githubLogin: String?
}

// MARK: - BriefingSecurity

/// "Security Debt" section payload.
struct BriefingSecurity: Sendable {

    /// The editorial verdict shown under the section header.
    let verdict: String

    /// Per-category security totals (Dependabot, Code Scanning, Secrets).
    let buckets: [BriefingSecurityBucket]
}

// MARK: - BriefingSecurityBucket

/// A single security category bucket used inside ``BriefingSecurity``.
struct BriefingSecurityBucket: Sendable {

    /// The bucket label, e.g. `"Dependabot"`.
    let name: String

    /// The count of open alerts in this bucket.
    let open: Int

    /// Change in open-alert count relative to the prior week.
    let delta: Int

    /// The number of alerts at `"critical"` severity within this bucket.
    let critical: Int
}

// MARK: - BriefingRepoHealth

/// A per-repository security health row shown at the bottom of the briefing.
struct BriefingRepoHealth: Sendable {

    /// The repository display name.
    let name: String

    /// The total count of open security alerts.
    let openAlerts: Int

    /// A normalized health score (`0`–`100`, higher = healthier).
    let score: Int

    /// When `true`, the row is rendered with the red accent.
    let urgent: Bool
}
