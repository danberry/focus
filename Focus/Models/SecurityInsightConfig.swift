import Foundation

// MARK: - SecurityInsightConfig

/// Tunable thresholds for the security insight rules.
///
/// Centralizing thresholds makes the rules deterministic and lets tests flex the
/// boundaries without changing rule code. Defaults reflect the product spec.
struct SecurityInsightConfig: Sendable {

    /// The shared default configuration used by production code.
    static let `default` = SecurityInsightConfig()

    /// Minimum CVSS score that triggers the "high CVSS unchecked" rule.
    var cvssAlertThreshold: Double = 9.0

    /// Minimum age in days before a high-CVSS alert counts as "unchecked".
    var cvssAlertAgeDays: Int = 7

    /// Minimum repo count for a multi-repo critical-spread insight.
    var criticalSpreadMinRepos: Int = 2

    /// Age threshold (days) for the multi-repo critical-spread insight.
    var criticalSpreadAgeDays: Int = 14

    /// Age threshold (days) for an unassigned critical to be called "aging".
    var agingCriticalDays: Int = 21

    /// Minimum weeks of history required before trend rules can fire.
    var trendMinWeeks: Int = 3

    /// Minimum repo count for a shared-blast-radius insight.
    var blastRadiusMinRepos: Int = 3

    /// Minimum fraction of total open alerts one ecosystem must own to fire the concentration insight.
    var ecosystemConcentrationPct: Double = 0.70

    /// Minimum absolute alert count for the ecosystem-concentration insight.
    var ecosystemConcentrationMinCount: Int = 5

    /// SLA threshold in days for critical Dependabot alerts.
    var slaThresholdDays: Int = 30

    /// Minimum alert count for the Code Scanning rule-pattern insight.
    var rulePatternMinCount: Int = 3

    /// Minimum critical count with fixes available before the positive insight fires.
    var fixAvailableMinCritical: Int = 3

    /// Minimum consecutive clean weeks before the streak insight fires.
    var cleanStreakMinWeeks: Int = 3

    /// Minimum absolute alert reduction (week-over-week) to fire the drop insight.
    var significantDropDelta: Int = 5

    /// Minimum fractional alert reduction (week-over-week) to fire the drop insight.
    var significantDropPct: Double = 0.20
}
