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

    /// Verifies that the placeholder shipping sparkline contains at most ten values.
    @Test func placeholderShippingSparkHasTenOrFewerValues() {
        #expect(Briefing.placeholder.kpis.shipping.spark.count <= 10)
    }

    /// Verifies that the placeholder security sparkline contains at most ten values.
    @Test func placeholderSecuritySparkHasTenOrFewerValues() {
        #expect(Briefing.placeholder.kpis.security.spark.count <= 10)
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
}
