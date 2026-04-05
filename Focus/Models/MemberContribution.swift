import Foundation
import SwiftData

// MARK: - MemberContribution

@Model
final class MemberContribution {
    var commits: Int
    var pullRequests: Int
    var reviews: Int
    var issues: Int
    var periodStart: Date
    var periodEnd: Date
    var fetchedAt: Date
    var member: Member?

    init(
        commits: Int,
        pullRequests: Int,
        reviews: Int,
        issues: Int,
        periodStart: Date,
        periodEnd: Date,
        fetchedAt: Date
    ) {
        self.commits = commits
        self.pullRequests = pullRequests
        self.reviews = reviews
        self.issues = issues
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.fetchedAt = fetchedAt
    }
}
