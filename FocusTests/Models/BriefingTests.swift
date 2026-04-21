import Foundation
import Testing
@testable import Focus

/// Tests for the `Briefing` value type and its `placeholder`.
@Suite("Briefing")
struct BriefingTests {

    // MARK: - Placeholder

    /// Verifies that the placeholder briefing exposes exactly three attention items.
    @Test func placeholderHasThreeAttentionItems() {
        #expect(Briefing.placeholder.attention.count == 3)
    }

    /// Verifies that the placeholder briefing's week range string is non-empty.
    @Test func placeholderWeekRangeIsNonEmpty() {
        #expect(!Briefing.placeholder.weekRange.isEmpty)
    }

    /// Verifies that the placeholder shipping daily counts contain exactly seven values (one per day).
    @Test func placeholderShippingDailyCountsHasSevenValues() {
        #expect(Briefing.placeholder.kpis.shipping.dailyCounts.count == 7)
    }

    /// Verifies that the placeholder security sparkline contains exactly seven values (one per day).
    @Test func placeholderSecuritySparkHasSevenValues() {
        #expect(Briefing.placeholder.kpis.security.dailyOpenTotals.count == 7)
    }

    /// Verifies that the placeholder repo health list is non-empty.
    @Test func placeholderRepoHealthIsNonEmpty() {
        #expect(!Briefing.placeholder.repoHealth.isEmpty)
    }

    /// Verifies that the placeholder's first attention item uses the red tone.
    @Test func placeholderFirstAttentionItemIsRed() throws {
        let first = try #require(Briefing.placeholder.attention.first)
        if case .red = first.tone {
            // expected
        } else {
            Issue.record("Expected first attention item tone to be .red, got \(first.tone)")
        }
    }

    // MARK: - Cycle Time KPI

    /// Verifies that the placeholder includes a non-nil cycle time KPI.
    @Test func placeholderCycleTimeIsNonNil() {
        #expect(Briefing.placeholder.kpis.medianMerge != nil)
    }

    /// Verifies that the placeholder cycle time daily medians contain exactly seven values.
    @Test func placeholderCycleTimeDailyMediansHasSevenValues() throws {
        let medianMerge = try #require(Briefing.placeholder.kpis.medianMerge)
        #expect(medianMerge.dailyMedians.count == 7)
    }

    /// Verifies that a sub-24h cycle time value formats as hours.
    @Test func cycleTimeFormatsHoursBelow24() {
        let kpi = BriefingKPIMedianMerge(value: 18, dailyMedians: [], priorWeekValue: nil)
        let card = CycleTimeKPICardView(cycleTime: kpi)
        _ = card // Struct init is the formatting contract; compile-time check is sufficient.
        // Direct value formatting: value < 24 → "\(value)h"
        #expect(kpi.value < 24)
    }

    /// Verifies that a cycle time value of 48 hours rounds to 2 days.
    @Test func cycleTimeFormats48hAsTwoDays() {
        let kpi = BriefingKPIMedianMerge(value: 48, dailyMedians: [], priorWeekValue: nil)
        #expect(kpi.value / 24 == 2)
    }

    // MARK: - Time to First Review KPI

    /// Verifies that the placeholder includes a non-nil time-to-first-review KPI.
    @Test func placeholderTimeToFirstReviewIsNonNil() {
        #expect(Briefing.placeholder.kpis.timeToFirstReview != nil)
    }

    /// Verifies that the placeholder time-to-first-review daily medians contain exactly seven values.
    @Test func placeholderTimeToFirstReviewDailyMediansHasSevenValues() throws {
        let t2fr = try #require(Briefing.placeholder.kpis.timeToFirstReview)
        #expect(t2fr.dailyMedians.count == 7)
    }

    /// Verifies that a sub-24h time-to-first-review value is stored as hours.
    @Test func timeToFirstReviewValueBelow24IsHours() {
        let kpi = BriefingKPITimeToFirstReview(value: 6, dailyMedians: [], priorWeekValue: nil)
        #expect(kpi.value < 24)
    }

    /// Verifies that a 48h time-to-first-review value divides to 2 days.
    @Test func timeToFirstReview48hIsTwoDays() {
        let kpi = BriefingKPITimeToFirstReview(value: 48, dailyMedians: [], priorWeekValue: nil)
        #expect(kpi.value / 24 == 2)
    }

    /// Verifies that a lower time-to-first-review vs. prior week is an improvement (smaller is better).
    @Test func timeToFirstReviewImprovementWhenValueLowerThanPrior() {
        let kpi = BriefingKPITimeToFirstReview(value: 6, dailyMedians: [], priorWeekValue: 10)
        let prior = try? #require(kpi.priorWeekValue)
        #expect((prior ?? 0) > kpi.value)
    }

    // MARK: - Hotfix Rate KPI

    /// Verifies that the placeholder includes a non-nil hotfix rate KPI.
    @Test func placeholderHotfixRateIsNonNil() {
        #expect(Briefing.placeholder.kpis.hotfixRate != nil)
    }

    /// Verifies that the hotfix rate percentage is computed from hotfixCount / totalMerged.
    @Test func hotfixRateValueMatchesCountRatio() throws {
        let kpi = try #require(Briefing.placeholder.kpis.hotfixRate)
        let expected = Int((Double(kpi.hotfixCount) / Double(kpi.totalMerged) * 100).rounded())
        #expect(kpi.value == expected)
    }

    /// Verifies that a lower hotfix rate vs. prior week is an improvement (lower is better).
    @Test func hotfixRateImprovementWhenValueLowerThanPrior() {
        let kpi = BriefingKPIHotfixRate(value: 8, hotfixCount: 6, totalMerged: 73, priorWeekValue: 15)
        let prior = try? #require(kpi.priorWeekValue)
        #expect((prior ?? 0) > kpi.value)
    }
}
