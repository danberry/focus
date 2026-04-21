import Foundation

// MARK: - SecurityInsightRule

/// Protocol for a single security insight rule.
///
/// Rules are pure functions of the input snapshot and config. Each one evaluates
/// independently and either fires (returning a ``SecurityInsight``) or passes.
protocol SecurityInsightRule: Sendable {

    /// Evaluates the rule against the input snapshot.
    ///
    /// - Parameters:
    ///   - input: The security snapshot assembled by ``BriefingService``.
    ///   - config: Tunable thresholds controlling when the rule fires.
    /// - Returns: A ``SecurityInsight`` when the rule fires, or `nil` otherwise.
    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight?
}

// MARK: - SecurityInsight

/// The per-domain output type for security rules.
///
/// Wraps a shared ``BriefingInsight`` payload together with the concrete
/// ``SecurityInsightKind`` that produced it, so tests and the aggregator can
/// assert on the rule identity without parsing strings.
struct SecurityInsight: Sendable {

    /// The concrete rule + data that produced this insight.
    let kind: SecurityInsightKind

    /// The display-ready payload.
    let briefingInsight: BriefingInsight

    /// Forwards to ``BriefingInsight/priority`` for convenient ranking.
    var priority: BriefingInsightPriority { briefingInsight.priority }

    /// Forwards to ``BriefingInsight/tone``.
    var tone: BriefingTone { briefingInsight.tone }
}

// MARK: - SecurityInsightGenerator

/// Evaluates all security rules, ranks the firing ones, and exposes the top pick.
///
/// The generator owns the rule registry and is the single entry point used by
/// ``BriefingService``. Priorities break ties by rule-registration order.
struct SecurityInsightGenerator: Sendable {

    /// Shared default generator using ``SecurityInsightConfig/default``.
    static let `default` = SecurityInsightGenerator()

    /// Tunable thresholds passed to every rule.
    let config: SecurityInsightConfig

    /// Registered rules. Order is the tie-breaker within a priority bucket.
    private let rules: [any SecurityInsightRule]

    /// Creates a generator backed by the given config and the full Tier 1 + Tier 2 rule set.
    init(config: SecurityInsightConfig = .default) {
        self.config = config
        self.rules = [
            // P0
            PubliclyLeakedActiveSecretRule(),
            PushProtectionBypassedRule(),
            // P1
            HighCvssUncheckedRule(),
            MultiRepoCriticalSpreadRule(),
            AgingUnassignedCriticalsRule(),
            CriticalAlertsInRepoRule(),
            // P2 — Tier 1
            MultiRepoSecretRule(),
            SharedBlastRadiusRule(),
            EcosystemConcentrationRule(),
            SLABreachRule(),
            CodeScanningRulePatternRule(),
            // P2 — Tier 2 (historical trend; no-ops until snapshots accumulate)
            AlertDebtTrendRule(),
            NewRepoAtRiskRule(),
            // P3 — Tier 2 (positive signals; no-ops until snapshots exist)
            CriticalBacklogClearedRule(),
            RepoWentCleanRule(),
            AlertCountDroppedRule(),
            CleanStreakRule(),
            // P3 — Tier 1
            FixesAvailableRule()
        ]
    }

    /// Returns every firing insight, sorted highest-priority first.
    ///
    /// Ties within a priority bucket preserve rule-registration order.
    func generate(_ input: SecurityInsightInput) -> [SecurityInsight] {
        let fired = rules.compactMap { $0.evaluate(input, config: config) }
        return fired.sorted { $0.priority < $1.priority }
    }

    /// Returns the single highest-priority firing insight, or `nil` if none fire.
    func topInsight(_ input: SecurityInsightInput) -> SecurityInsight? {
        generate(input).first
    }
}

// MARK: - P0 Rules

/// Fires when any secret alert is both publicly leaked and still active. Highest urgency.
struct PubliclyLeakedActiveSecretRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let leaked = input.secretAlerts.filter { $0.publiclyLeaked && $0.validity == "active" }
        guard !leaked.isEmpty else { return nil }
        // Prefer a bypassed-AND-leaked alert if present; it's the worst case.
        let chosen = leaked.first(where: { $0.pushProtectionBypassed }) ?? leaked[0]
        let title = "An active **\(chosen.secretTypeDisplayName)** has been publicly exposed."
        let meta = "Revoke and rotate immediately · \(chosen.repoName)"
        return SecurityInsight(
            kind: .publiclyLeakedSecret(secretType: chosen.secretTypeDisplayName, repoName: chosen.repoName),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p0_immediate,
                tone: .red,
                title: title,
                meta: meta,
                actionLabel: "View alert →"
            )
        )
    }
}

/// Fires when a developer bypassed push protection to commit a secret.
struct PushProtectionBypassedRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let bypassed = input.secretAlerts.filter { $0.pushProtectionBypassed }
        guard !bypassed.isEmpty else { return nil }
        let uniqueRepos = Array(Set(bypassed.map(\.repoName))).sorted()
        // "Most recent bypass" isn't present on the summary; first unique repo stands in for now.
        let primaryRepo = uniqueRepos.first ?? bypassed[0].repoName

        let title: String
        if uniqueRepos.count <= 1 {
            title = "Push protection was bypassed in **\(primaryRepo)**."
        } else {
            let otherCount = uniqueRepos.count - 1
            let suffix = otherCount == 1 ? "1 other repo" : "\(otherCount) other repos"
            title = "Push protection bypassed in **\(primaryRepo)** and \(suffix)."
        }
        return SecurityInsight(
            kind: .pushProtectionBypassed(repoName: primaryRepo),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p0_immediate,
                tone: .red,
                title: title,
                meta: "A secret was committed despite the protection policy",
                actionLabel: "Review alert →"
            )
        )
    }
}

// MARK: - P1 Rules

/// Fires when high-CVSS alerts have aged past the configured attention window.
struct HighCvssUncheckedRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let qualifying = input.dependabotSummaries.filter { alert in
            guard let cvss = alert.cvssScore else { return false }
            return cvss >= config.cvssAlertThreshold && alert.ageInDays >= config.cvssAlertAgeDays
        }
        guard !qualifying.isEmpty else { return nil }
        let count = qualifying.count
        let maxCvss = qualifying.compactMap(\.cvssScore).max() ?? config.cvssAlertThreshold
        let oldestDays = qualifying.map(\.ageInDays).max() ?? config.cvssAlertAgeDays
        let repoCount = Set(qualifying.map(\.repoName)).count
        let alertWord = count == 1 ? "alert" : "alerts"
        let repoWord = repoCount == 1 ? "repo" : "repos"
        let threshold = formatCvss(config.cvssAlertThreshold)
        let maxFormatted = formatCvss(maxCvss)
        return SecurityInsight(
            kind: .highCvssUnchecked(count: count, maxCvss: maxCvss, oldestDays: oldestDays),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p1_urgent,
                tone: .red,
                title: "\(count) \(alertWord) with CVSS ≥ \(threshold) open for \(oldestDays) days.",
                meta: "Highest score: \(maxFormatted) · across \(repoCount) \(repoWord)",
                actionLabel: "View alerts →"
            )
        )
    }

    /// Formats a CVSS score with at most one decimal, trimming a trailing `.0`.
    private func formatCvss(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}

/// Fires when multiple repos have long-aging critical alerts open.
struct MultiRepoCriticalSpreadRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let qualifying = input.repoDetails.filter { detail in
            detail.criticalCount > 0
                && (detail.oldestCriticalAgeInDays ?? 0) >= config.criticalSpreadAgeDays
        }
        guard qualifying.count >= config.criticalSpreadMinRepos else { return nil }
        let repos = qualifying.map(\.repoName)
        let count = repos.count
        let ageDays = qualifying.compactMap(\.oldestCriticalAgeInDays).max() ?? config.criticalSpreadAgeDays
        let metaList = repos.prefix(3).joined(separator: " · ")
        return SecurityInsight(
            kind: .multiRepoCriticalSpread(repos: repos, ageDays: ageDays),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p1_urgent,
                tone: .red,
                title: "\(count) repos have had critical alerts open for \(config.criticalSpreadAgeDays)+ days.",
                meta: metaList,
                actionLabel: "View security →"
            )
        )
    }
}

/// Fires when critical alerts have aged past the threshold without an owner.
struct AgingUnassignedCriticalsRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let qualifying = input.dependabotSummaries.filter { alert in
            alert.severity == "critical"
                && !alert.hasAssignee
                && alert.ageInDays >= config.agingCriticalDays
        }
        guard !qualifying.isEmpty else { return nil }
        let count = qualifying.count
        let oldest = qualifying.map(\.ageInDays).max() ?? config.agingCriticalDays
        let alertWord = count == 1 ? "alert" : "alerts"
        return SecurityInsight(
            kind: .agingUnassignedCriticals(count: count, oldestDays: oldest),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p1_urgent,
                tone: .red,
                title: "\(count) critical \(alertWord) unassigned after \(oldest) days.",
                meta: "No owner assigned · escalate to security team",
                actionLabel: "Assign alerts →"
            )
        )
    }
}

/// Fallback P1 rule — surfaces the repo with the most open critical alerts.
///
/// This preserves the original (pre-engine) behavior as the lowest-priority
/// P1 catch-all. Fires whenever any repo has `criticalCount > 0`.
struct CriticalAlertsInRepoRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        guard let top = input.repoDetails
            .filter({ $0.criticalCount > 0 })
            .max(by: { $0.criticalCount < $1.criticalCount })
        else { return nil }
        let alertWord = top.criticalCount == 1 ? "alert" : "alerts"
        return SecurityInsight(
            kind: .criticalAlertsInRepo(repoName: top.repoName, count: top.criticalCount),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p1_urgent,
                tone: .red,
                title: "\(top.criticalCount) critical \(alertWord) open in **\(top.repoName)**.",
                meta: "Escalate to security review",
                actionLabel: "Open alerts →"
            )
        )
    }
}

// MARK: - P2 Rules

/// Fires when the same secret type is exposed across multiple repositories.
struct MultiRepoSecretRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let multi = input.secretAlerts.filter { $0.multiRepo }
        guard !multi.isEmpty else { return nil }
        // Group by secret type, counting unique repos per type.
        var reposByType: [String: Set<String>] = [:]
        for alert in multi {
            reposByType[alert.secretTypeDisplayName, default: []].insert(alert.repoName)
        }
        guard let (type, repos) = reposByType.max(by: { $0.value.count < $1.value.count }),
              repos.count > 1
        else { return nil }
        return SecurityInsight(
            kind: .multiRepoSecret(secretType: type, repoCount: repos.count),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p2_notable,
                tone: .red,
                title: "A **\(type)** credential is exposed in \(repos.count) repos.",
                meta: "Same secret detected across multiple repositories",
                actionLabel: "View alerts →"
            )
        )
    }
}

/// Fires when a single GHSA affects enough distinct repos to constitute a blast radius.
struct SharedBlastRadiusRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        // Group by GHSA; track unique repos and a representative package name.
        var groups: [String: (repos: Set<String>, packageName: String)] = [:]
        for alert in input.dependabotSummaries where !alert.ghsaId.isEmpty {
            var entry = groups[alert.ghsaId] ?? (repos: [], packageName: alert.packageName)
            entry.repos.insert(alert.repoName)
            groups[alert.ghsaId] = entry
        }
        guard let (ghsa, entry) = groups.max(by: { $0.value.repos.count < $1.value.repos.count }),
              entry.repos.count >= config.blastRadiusMinRepos
        else { return nil }
        let repos = entry.repos.sorted()
        return SecurityInsight(
            kind: .sharedBlastRadius(packageName: entry.packageName, repoCount: repos.count, ghsaId: ghsa),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p2_notable,
                tone: .red,
                title: "**\(entry.packageName)** affects \(repos.count) repos — one advisory, \(repos.count) fixes needed.",
                meta: "GHSA: \(ghsa) · \(repos.joined(separator: " · "))",
                actionLabel: "View advisory →"
            )
        )
    }
}

/// Fires when one ecosystem dominates the Dependabot backlog.
struct EcosystemConcentrationRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let total = input.dependabotSummaries.count
        guard total >= config.ecosystemConcentrationMinCount else { return nil }
        var counts: [String: Int] = [:]
        for alert in input.dependabotSummaries where !alert.ecosystem.isEmpty {
            counts[alert.ecosystem, default: 0] += 1
        }
        guard let (ecosystem, count) = counts.max(by: { $0.value < $1.value }) else { return nil }
        let fraction = Double(count) / Double(total)
        guard count >= config.ecosystemConcentrationMinCount,
              fraction >= config.ecosystemConcentrationPct
        else { return nil }
        let pct = Int((fraction * 100).rounded())
        return SecurityInsight(
            kind: .ecosystemConcentration(ecosystem: ecosystem, count: count, totalOpen: total),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p2_notable,
                tone: .red,
                title: "\(pct)% of Dependabot alerts are \(ecosystem) packages.",
                meta: "\(count) of \(total) open alerts share the same ecosystem",
                actionLabel: "View alerts →"
            )
        )
    }
}

/// Fires when a repo has critical alerts past the policy SLA threshold.
struct SLABreachRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let qualifying = input.dependabotSummaries.filter { alert in
            alert.severity == "critical" && alert.ageInDays >= config.slaThresholdDays
        }
        guard !qualifying.isEmpty else { return nil }
        // Group by repo, keeping the oldest alert's age per repo.
        var oldestByRepo: [String: Int] = [:]
        for alert in qualifying {
            oldestByRepo[alert.repoName] = max(oldestByRepo[alert.repoName] ?? 0, alert.ageInDays)
        }
        guard let (repoName, age) = oldestByRepo.max(by: { $0.value < $1.value }) else { return nil }
        return SecurityInsight(
            kind: .slaBreach(repoName: repoName, ageDays: age, thresholdDays: config.slaThresholdDays),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p2_notable,
                tone: .red,
                title: "**\(repoName)** has had critical alerts open \(age) days.",
                meta: "Exceeds \(config.slaThresholdDays)-day policy threshold",
                actionLabel: "View alerts →"
            )
        )
    }
}

/// Fires when many Code Scanning alerts trace back to a single rule.
struct CodeScanningRulePatternRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let alertsWithRule = input.codeScanningAlerts.compactMap { alert -> (String, String)? in
            guard let id = alert.ruleId else { return nil }
            return (id, alert.ruleName)
        }
        let total = input.codeScanningAlerts.count
        guard !alertsWithRule.isEmpty else { return nil }

        // Group by rule id, remembering a display name.
        var counts: [String: (count: Int, name: String)] = [:]
        for (id, name) in alertsWithRule {
            var entry = counts[id] ?? (count: 0, name: name)
            entry.count += 1
            counts[id] = entry
        }
        guard let (ruleId, entry) = counts.max(by: { $0.value.count < $1.value.count }),
              entry.count >= config.rulePatternMinCount
        else { return nil }
        return SecurityInsight(
            kind: .codeScanningRulePattern(ruleId: ruleId, ruleName: entry.name, count: entry.count, total: total),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p2_notable,
                tone: .red,
                title: "\(entry.count) of \(total) Code Scanning alerts are the same rule.",
                meta: "\(entry.name) · \(ruleId)",
                actionLabel: "View rule →"
            )
        )
    }
}

// MARK: - P2 Tier 2 Rules

/// Fires when the total open alert count has grown for N consecutive weeks.
///
/// Requires at least `config.trendMinWeeks` entries in `weekHistory`. The check
/// looks at the last `trendMinWeeks` snapshots (oldest first) and fires only when
/// each week's `totalOpen` strictly exceeds the previous week's.
struct AlertDebtTrendRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let history = input.weekHistory
        guard history.count >= config.trendMinWeeks else { return nil }
        let recent = Array(history.suffix(config.trendMinWeeks))
        for i in 1..<recent.count {
            guard recent[i].totalOpen > recent[i - 1].totalOpen else { return nil }
        }
        let delta = recent[recent.count - 1].totalOpen - recent[0].totalOpen
        return SecurityInsight(
            kind: .alertDebtTrend(weeks: config.trendMinWeeks, delta: delta),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p2_notable,
                tone: .red,
                title: "Open alerts have grown for \(config.trendMinWeeks) consecutive weeks.",
                meta: "+\(delta) alerts over the past \(config.trendMinWeeks) weeks",
                actionLabel: "View security →"
            )
        )
    }
}

/// Fires when a repo had zero critical alerts last week but has criticals this week.
struct NewRepoAtRiskRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        guard let prior = input.priorWeekTotals else { return nil }
        let newAtRisk = input.repoDetails.filter { detail in
            detail.criticalCount > 0 && (prior.repoCriticalCounts[detail.repoName] ?? 0) == 0
        }
        guard let first = newAtRisk.first else { return nil }
        let count = newAtRisk.count
        let title: String
        let meta: String
        if count == 1 {
            title = "**\(first.repoName)** has new critical alerts — clean last week."
            meta = "Critical alert introduced this week"
        } else {
            title = "\(count) repos have new critical alerts — all clean last week."
            meta = newAtRisk.prefix(3).map(\.repoName).joined(separator: " · ")
        }
        return SecurityInsight(
            kind: .newRepoAtRisk(repoName: first.repoName),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p2_notable,
                tone: .red,
                title: title,
                meta: meta,
                actionLabel: "View alerts →"
            )
        )
    }
}

// MARK: - P3 Rules

/// Fires when the entire critical backlog was cleared week-over-week.
struct CriticalBacklogClearedRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        guard let prior = input.priorWeekTotals, prior.totalCritical > 0 else { return nil }
        let currentCritical = input.repoDetails.reduce(0) { $0 + $1.criticalCount }
        guard currentCritical == 0 else { return nil }
        let n = prior.totalCritical
        let alertWord = n == 1 ? "alert" : "alerts"
        return SecurityInsight(
            kind: .criticalBacklogCleared(clearedCount: n),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p3_positive,
                tone: .blue,
                title: "Critical backlog cleared — \(n) critical \(alertWord) resolved.",
                meta: "No open critical alerts this week",
                actionLabel: "View security →"
            )
        )
    }
}

/// Fires when a previously-noisy repo now has zero open alerts.
struct RepoWentCleanRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        guard let prior = input.priorWeekTotals else { return nil }
        // Repos that had criticals last week and now have zero open alerts of any kind.
        let cleanRepos = prior.repoCriticalCounts
            .filter { $0.value > 0 }
            .keys
            .filter { repoName in
                input.repoDetails.first(where: { $0.repoName == repoName })?.openAlerts == 0
            }
            .sorted()
        guard let first = cleanRepos.first else { return nil }
        return SecurityInsight(
            kind: .repoWentClean(repoName: first),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p3_positive,
                tone: .blue,
                title: "**\(first)** is now alert-free.",
                meta: "Had critical alerts last week — resolved this week",
                actionLabel: "View security →"
            )
        )
    }
}

/// Fires when the total open alert count dropped significantly week-over-week.
///
/// The rule fires when either the absolute drop meets `config.significantDropDelta`
/// or the fractional drop meets `config.significantDropPct` (whichever is easier to satisfy).
struct AlertCountDroppedRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        guard let prior = input.priorWeekTotals,
              let current = input.currentWeekTotals,
              prior.totalOpen > 0 else { return nil }
        let delta = prior.totalOpen - current.totalOpen
        guard delta > 0 else { return nil }
        let dropPct = Double(delta) / Double(prior.totalOpen)
        guard delta >= config.significantDropDelta || dropPct >= config.significantDropPct else { return nil }
        return SecurityInsight(
            kind: .alertCountDropped(delta: delta, fromTotal: prior.totalOpen),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p3_positive,
                tone: .blue,
                title: "Open alerts dropped by \(delta) this week.",
                meta: "From \(prior.totalOpen) to \(current.totalOpen) open alerts",
                actionLabel: "View security →"
            )
        )
    }
}

/// Fires when no critical alerts have appeared for N consecutive weeks.
struct CleanStreakRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let history = input.weekHistory
        guard !history.isEmpty else { return nil }
        var streak = 0
        for week in history.reversed() {
            guard week.totalCritical == 0 else { break }
            streak += 1
        }
        guard streak >= config.cleanStreakMinWeeks else { return nil }
        let weekWord = streak == 1 ? "week" : "weeks"
        return SecurityInsight(
            kind: .cleanStreak(weeks: streak),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p3_positive,
                tone: .blue,
                title: "No critical alerts for \(streak) \(weekWord) in a row.",
                meta: "Keep it up — \(streak)-week clean streak",
                actionLabel: "View security →"
            )
        )
    }
}

/// Fires when a meaningful share of critical Dependabot alerts have upgrades ready.
struct FixesAvailableRule: SecurityInsightRule {

    func evaluate(_ input: SecurityInsightInput, config: SecurityInsightConfig) -> SecurityInsight? {
        let criticals = input.dependabotSummaries.filter { $0.severity == "critical" }
        let fixable = criticals.filter(\.fixAvailable)
        guard fixable.count >= config.fixAvailableMinCritical else { return nil }
        let upgradeWord = fixable.count == 1 ? "Upgrade" : "Upgrades"
        return SecurityInsight(
            kind: .fixesAvailable(count: fixable.count, criticalCount: criticals.count),
            briefingInsight: BriefingInsight(
                domain: .security,
                priority: .p3_positive,
                tone: .blue,
                title: "Fix available for \(fixable.count) of \(criticals.count) critical Dependabot alerts.",
                meta: "\(upgradeWord) ready — no waiting on upstream",
                actionLabel: "View fixes →"
            )
        )
    }
}
