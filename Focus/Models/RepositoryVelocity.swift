import Foundation
import SwiftData

// MARK: - VelocityPeriod

enum VelocityPeriod: String, CaseIterable {
    case sevenDays = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"
    case yearToDate = "YTD"
}

// MARK: - VelocityComparison

struct VelocityComparison {
    let current: Int
    let prior: Int

    var delta: Int { current - prior }

    var percentChange: Double? {
        guard prior > 0 else { return nil }
        return Double(delta) / Double(prior) * 100.0
    }

    enum Trend { case up, down, flat }

    var trend: Trend {
        if delta > 0 { return .up }
        if delta < 0 { return .down }
        return .flat
    }
}

// MARK: - RepositoryVelocity

@Model
final class RepositoryVelocity {
    var periodType: String      // VelocityPeriod.rawValue
    var currentCount: Int
    var priorCount: Int
    var periodStart: Date       // start of the current window
    var periodEnd: Date         // end of the current window (today at sync time)
    var fetchedAt: Date
    var repository: SavedRepository?

    init(
        periodType: String,
        currentCount: Int,
        priorCount: Int,
        periodStart: Date,
        periodEnd: Date,
        fetchedAt: Date
    ) {
        self.periodType = periodType
        self.currentCount = currentCount
        self.priorCount = priorCount
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.fetchedAt = fetchedAt
    }

    var comparison: VelocityComparison {
        VelocityComparison(current: currentCount, prior: priorCount)
    }
}
