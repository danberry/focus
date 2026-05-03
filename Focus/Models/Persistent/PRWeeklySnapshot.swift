import Foundation
import SwiftData

// MARK: - PRWeeklySnapshot

/// A weekly aggregate of merged PR metrics, persisted so the briefing can skip
/// the paginated GitHub fetch for the prior week.
///
/// One record is written per (weekStart, repoFingerprint) pair. Re-generation
/// within the same week updates the record in place.
@Model
final class PRWeeklySnapshot {

    // MARK: - Stored Properties

    /// The first day of the briefing week (midnight, user's locale).
    var weekStart: Date = Date()

    /// Sorted `"owner/name"` pairs joined by `","` — identifies the exact set
    /// of repos this snapshot covers so scope changes cause a natural cache miss.
    var repoFingerprint: String = ""

    var medianHours: Int?
    var dailyCounts: [Int] = []
    var medianPRSize: Int?
    var dailyPRSizeMedians: [Int] = []
    var dailyCycleTimeMedians: [Int] = []
    var medianFirstReviewHours: Int?
    var dailyFirstReviewMedians: [Int] = []
    var hotfixCount: Int = 0
    var totalMerged: Int = 0
    var unreviewedCount: Int = 0
    var totalPRCount: Int = 0
    var ciPassPct: Int?

    /// JSON-encoded `[String: Int]` — SwiftData does not persist dictionaries directly.
    var repoCountsJSON: Data?

    // MARK: - Derived

    var repoCounts: [String: Int] {
        guard let data = repoCountsJSON else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    // MARK: - Init

    init(
        weekStart: Date,
        repoFingerprint: String,
        medianHours: Int?,
        dailyCounts: [Int],
        medianPRSize: Int?,
        dailyPRSizeMedians: [Int],
        dailyCycleTimeMedians: [Int],
        medianFirstReviewHours: Int?,
        dailyFirstReviewMedians: [Int],
        hotfixCount: Int,
        totalMerged: Int,
        unreviewedCount: Int,
        totalPRCount: Int,
        ciPassPct: Int?,
        repoCounts: [String: Int]
    ) {
        self.weekStart = weekStart
        self.repoFingerprint = repoFingerprint
        self.medianHours = medianHours
        self.dailyCounts = dailyCounts
        self.medianPRSize = medianPRSize
        self.dailyPRSizeMedians = dailyPRSizeMedians
        self.dailyCycleTimeMedians = dailyCycleTimeMedians
        self.medianFirstReviewHours = medianFirstReviewHours
        self.dailyFirstReviewMedians = dailyFirstReviewMedians
        self.hotfixCount = hotfixCount
        self.totalMerged = totalMerged
        self.unreviewedCount = unreviewedCount
        self.totalPRCount = totalPRCount
        self.ciPassPct = ciPassPct
        self.repoCountsJSON = try? JSONEncoder().encode(repoCounts)
    }
}
