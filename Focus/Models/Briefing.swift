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
                actionLabel: "Open alerts →"
            ),
            BriefingAttentionItem(
                n: "02",
                tone: .blue,
                title: "Priya Shah idle 6 days.",
                meta: "Last commit: Apr 12 · Platform team",
                actionLabel: "DM Priya →"
            ),
            BriefingAttentionItem(
                n: "03",
                tone: .neutral,
                title: "Only 4 PRs merged in `mobile-ios`.",
                meta: "Down from 11 the prior week",
                actionLabel: "See repo →"
            )
        ],
        kpis: BriefingKPIs(
            shipping: BriefingKPIShipping(
                value: 73,
                dailyCounts: [8, 12, 9, 15, 11, 14, 4]
            ),
            security: BriefingKPISecurity(
                value: 48,
                critical: 12,
                spark: [0.4, 0.5, 0.5, 0.6, 0.7, 0.7, 0.8, 0.8, 0.9, 1.0]
            ),
            idle: BriefingKPIIdle(value: 2, delta: 1),
            medianMergeHours: nil,
            ciPassPct: nil,
            releases: nil
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

    /// Median time from PR open to merge in hours, or `nil` if not tracked.
    let medianMergeHours: Int?

    /// CI pass rate as a percent (0–100), or `nil` if not tracked.
    let ciPassPct: Int?

    /// GitHub release count across all tracked repos in the last 7 days, or `nil` if not tracked.
    let releases: Int?
}

// MARK: - BriefingKPIShipping

/// Shipping KPI (merged PR total + 7-day bar chart).
struct BriefingKPIShipping: Sendable {

    /// Total merged pull requests for the week across all tracked repos.
    let value: Int

    /// Raw PR counts per day for the 7-day report period, ordered oldest to newest.
    let dailyCounts: [Int]
}

// MARK: - BriefingKPISecurity

/// Security KPI (open alert total, critical count, and sparkline).
struct BriefingKPISecurity: Sendable {

    /// Total open security alerts across all tracked repos.
    let value: Int

    /// The number of alerts at `"critical"` severity.
    let critical: Int

    /// A sparkline of up to 10 normalized values (`0.0`–`1.0`).
    let spark: [Double]
}

// MARK: - BriefingKPIIdle

/// Idle KPI (count of members with zero activity + week-over-week delta).
struct BriefingKPIIdle: Sendable {

    /// The number of tracked members with zero contributions this week.
    let value: Int

    /// Change relative to the prior week (positive = more idle members now).
    let delta: Int
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
