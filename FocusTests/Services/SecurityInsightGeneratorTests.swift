import Foundation
import Testing
@testable import Focus

/// Tests for the Tier 3 security insight rules.
///
/// Rules are pure functions of `SecurityInsightInput` and `SecurityInsightConfig`,
/// so no SwiftData or networking is needed.
@Suite("SecurityInsightGenerator — Tier 3")
struct SecurityInsightGeneratorTests {

    // MARK: - Helpers

    private static let weekStart = Date(timeIntervalSince1970: 1_745_712_000) // Mon 2026-04-27 00:00 UTC

    private static func makeWeekInterval() -> DateInterval {
        DateInterval(start: weekStart, duration: 7 * 86_400)
    }

    /// Builds a minimal `SecurityInsightInput` with only `currentWeekTotals` populated.
    private func makeInput(
        opened: Int,
        closed: Int,
        repoClosedCounts: [String: Int] = [:]
    ) -> SecurityInsightInput {
        let totals = SecurityWeekTotals(
            weekStart: Self.weekStart,
            totalOpen: 10,
            totalCritical: 0,
            opened: opened,
            closed: closed,
            repoCriticalCounts: [:],
            repoClosedCounts: repoClosedCounts
        )
        return SecurityInsightInput(
            weekInterval: Self.makeWeekInterval(),
            dependabotSummaries: [],
            codeScanningAlerts: [],
            secretAlerts: [],
            repoDetails: [],
            currentWeekTotals: totals,
            priorWeekTotals: nil,
            weekHistory: []
        )
    }

    // MARK: - ClosureVelocityBeatIntakeRule

    /// Fires when closures outnumber opened alerts.
    @Test func closureVelocityBeatIntakeFiresWhenClosedExceedsOpened() {
        let rule = ClosureVelocityBeatIntakeRule()
        let input = makeInput(opened: 3, closed: 5)

        let result = rule.evaluate(input, config: .default)

        #expect(result != nil)
        guard case .closureVelocityBeatIntake(let closed, let opened) = result?.kind else {
            Issue.record("Expected .closureVelocityBeatIntake kind")
            return
        }
        #expect(closed == 5)
        #expect(opened == 3)
        #expect(result?.priority == .p3_positive)
        #expect(result?.tone == .blue)
    }

    /// Does not fire when closures equal opened alerts.
    @Test func closureVelocityBeatIntakeDoesNotFireWhenEqual() {
        let rule = ClosureVelocityBeatIntakeRule()
        let input = makeInput(opened: 4, closed: 4)

        #expect(rule.evaluate(input, config: .default) == nil)
    }

    /// Does not fire when closures are below opened alerts.
    @Test func closureVelocityBeatIntakeDoesNotFireWhenOpenedExceedsClosed() {
        let rule = ClosureVelocityBeatIntakeRule()
        let input = makeInput(opened: 10, closed: 2)

        #expect(rule.evaluate(input, config: .default) == nil)
    }

    /// Does not fire when `currentWeekTotals` is absent.
    @Test func closureVelocityBeatIntakeDoesNotFireWithoutTotals() {
        let rule = ClosureVelocityBeatIntakeRule()
        let input = SecurityInsightInput(
            weekInterval: Self.makeWeekInterval(),
            dependabotSummaries: [],
            codeScanningAlerts: [],
            secretAlerts: [],
            repoDetails: [],
            currentWeekTotals: nil,
            priorWeekTotals: nil,
            weekHistory: []
        )

        #expect(rule.evaluate(input, config: .default) == nil)
    }

    /// Title encodes the correct net reduction.
    @Test func closureVelocityBeatIntakeTitleShowsNetReduction() {
        let rule = ClosureVelocityBeatIntakeRule()
        let input = makeInput(opened: 2, closed: 7)

        let result = rule.evaluate(input, config: .default)

        #expect(result?.briefingInsight.title.contains("5") == true)
    }

    // MARK: - FastestResolvingRepoRule

    /// Fires and surfaces the repo with the highest closure count.
    @Test func fastestResolvingRepoFiresWithLeadingRepo() {
        let rule = FastestResolvingRepoRule()
        let input = makeInput(
            opened: 0,
            closed: 0,
            repoClosedCounts: ["alpha": 2, "beta": 7, "gamma": 4]
        )

        let result = rule.evaluate(input, config: .default)

        #expect(result != nil)
        guard case .fastestResolvingRepo(let repoName, let count) = result?.kind else {
            Issue.record("Expected .fastestResolvingRepo kind")
            return
        }
        #expect(repoName == "beta")
        #expect(count == 7)
        #expect(result?.priority == .p4_informational)
    }

    /// Does not fire when all repos have zero closures.
    @Test func fastestResolvingRepoDoesNotFireWithNoClosures() {
        let rule = FastestResolvingRepoRule()
        let input = makeInput(opened: 0, closed: 0, repoClosedCounts: [:])

        #expect(rule.evaluate(input, config: .default) == nil)
    }

    /// Does not fire when `currentWeekTotals` is absent.
    @Test func fastestResolvingRepoDoesNotFireWithoutTotals() {
        let rule = FastestResolvingRepoRule()
        let input = SecurityInsightInput(
            weekInterval: Self.makeWeekInterval(),
            dependabotSummaries: [],
            codeScanningAlerts: [],
            secretAlerts: [],
            repoDetails: [],
            currentWeekTotals: nil,
            priorWeekTotals: nil,
            weekHistory: []
        )

        #expect(rule.evaluate(input, config: .default) == nil)
    }

    /// Title names the leading repo.
    @Test func fastestResolvingRepoTitleNamesLeadingRepo() {
        let rule = FastestResolvingRepoRule()
        let input = makeInput(
            opened: 0,
            closed: 0,
            repoClosedCounts: ["focus-ios": 3]
        )

        let result = rule.evaluate(input, config: .default)

        #expect(result?.briefingInsight.title.contains("focus-ios") == true)
        #expect(result?.briefingInsight.title.contains("3") == true)
    }

    // MARK: - IntakeAcceleratingRule

    /// Fires when opened/closed ratio meets or exceeds the threshold.
    @Test func intakeAcceleratingFiresAtThreshold() {
        var config = SecurityInsightConfig.default
        config.intakeRatio = 2.0
        let rule = IntakeAcceleratingRule()
        let input = makeInput(opened: 10, closed: 5) // ratio = 2.0

        let result = rule.evaluate(input, config: config)

        #expect(result != nil)
        guard case .intakeAccelerating(let opened, let closed) = result?.kind else {
            Issue.record("Expected .intakeAccelerating kind")
            return
        }
        #expect(opened == 10)
        #expect(closed == 5)
        #expect(result?.priority == .p4_informational)
    }

    /// Fires when ratio exceeds (not just meets) the threshold.
    @Test func intakeAcceleratingFiresAboveThreshold() {
        var config = SecurityInsightConfig.default
        config.intakeRatio = 2.0
        let rule = IntakeAcceleratingRule()
        let input = makeInput(opened: 11, closed: 5) // ratio ≈ 2.2

        #expect(rule.evaluate(input, config: config) != nil)
    }

    /// Does not fire when ratio is below the threshold.
    @Test func intakeAcceleratingDoesNotFireBelowThreshold() {
        var config = SecurityInsightConfig.default
        config.intakeRatio = 2.0
        let rule = IntakeAcceleratingRule()
        let input = makeInput(opened: 9, closed: 5) // ratio = 1.8

        #expect(rule.evaluate(input, config: config) == nil)
    }

    /// Does not fire when closed is zero (undefined ratio).
    @Test func intakeAcceleratingDoesNotFireWithZeroClosures() {
        let rule = IntakeAcceleratingRule()
        let input = makeInput(opened: 20, closed: 0)

        #expect(rule.evaluate(input, config: .default) == nil)
    }

    /// Does not fire when `currentWeekTotals` is absent.
    @Test func intakeAcceleratingDoesNotFireWithoutTotals() {
        let rule = IntakeAcceleratingRule()
        let input = SecurityInsightInput(
            weekInterval: Self.makeWeekInterval(),
            dependabotSummaries: [],
            codeScanningAlerts: [],
            secretAlerts: [],
            repoDetails: [],
            currentWeekTotals: nil,
            priorWeekTotals: nil,
            weekHistory: []
        )

        #expect(rule.evaluate(input, config: .default) == nil)
    }

    /// Title encodes the ratio string.
    @Test func intakeAcceleratingTitleShowsRatio() {
        var config = SecurityInsightConfig.default
        config.intakeRatio = 2.0
        let rule = IntakeAcceleratingRule()
        let input = makeInput(opened: 10, closed: 4) // ratio = 2.5

        let result = rule.evaluate(input, config: config)

        #expect(result?.briefingInsight.title.contains("2.5") == true)
    }

    // MARK: - Generator integration

    /// The generator returns Tier 3 rules after all higher-priority rules.
    @Test func generatorRanksTier3AfterHigherPriorities() {
        let input = makeInput(opened: 2, closed: 6) // closures beat intake — P3

        let insights = SecurityInsightGenerator().generate(input)

        // Only Tier 3 rules can fire with this input (no alerts, just week totals).
        #expect(!insights.isEmpty)
        #expect(insights.allSatisfy { $0.priority >= .p3_positive })
    }
}
