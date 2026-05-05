import Foundation
import SwiftData

// MARK: - CommitActivityService

/// Fetches and persists per-day commit activity for GitHub repositories.
///
/// `CommitActivityService` calls the GitHub Stats API
/// (`/repos/{owner}/{repo}/stats/commit_activity`), which returns up to 52 weeks
/// of commit counts broken down by day. The last 26 weeks are persisted as
/// ``RepositoryCommitDay`` records, replacing any previously stored data on each sync.
///
/// Days with zero commits are not stored — a missing record implies a count of zero,
/// which keeps the SwiftData graph compact.
///
/// All network calls go through the injected ``RESTClient``.
struct CommitActivityService: Sendable {

    // MARK: - Properties

    /// The REST client used for all GitHub API calls.
    private let rest: RESTClient

    // MARK: - Init

    /// Creates a `CommitActivityService` backed by the given REST client.
    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Fetch (non-isolated, Sendable result)

    /// Fetches the last year of commit activity from the GitHub Stats API.
    ///
    /// Returns `nil` on any network or decoding error, including `202 Accepted`
    /// responses that GitHub returns when stats are first being computed. The
    /// caller should treat `nil` as "no data yet" and retry on the next sync cycle.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login.
    ///   - repo: The repository name.
    /// - Returns: An array of weekly commit-activity records, or `nil` on failure.
    func fetchCommitActivity(owner: String, repo: String) async -> [CommitActivityWeek]? {
        return try? await rest.get(path: Endpoint.commitActivity(owner: owner, repo: repo).path)
    }

    // MARK: - Apply (@MainActor, writes to SwiftData)

    /// Replaces all stored commit-activity records for a repository with fresh data.
    ///
    /// Only the last 26 weeks of `weeks` are persisted. Days with zero commits are
    /// skipped. Passing `nil` removes all existing records without inserting new ones.
    ///
    /// - Parameters:
    ///   - weeks: The fetched weekly activity records, or `nil` to clear existing data.
    ///   - repository: The repository whose commit activity is being updated.
    ///   - context: The SwiftData model context used to delete and insert records.
    @MainActor
    func applyCommitActivity(
        _ weeks: [CommitActivityWeek]?,
        to repository: SavedRepository,
        in context: ModelContext
    ) {
        // Full-replace: delete all existing records for this repository.
        for record in repository.commitActivity ?? [] {
            context.delete(record)
        }
        repository.commitActivity = []

        guard let weeks else { return }

        // Persist only the most recent 26 weeks.
        let recentWeeks = Array(weeks.suffix(26))

        for week in recentWeeks {
            let weekStart = Date(timeIntervalSince1970: TimeInterval(week.week))
            for (dayOffset, count) in week.days.enumerated() {
                guard count > 0 else { continue }
                let date = weekStart.addingTimeInterval(TimeInterval(dayOffset * 86_400))
                let record = RepositoryCommitDay(date: date, commitCount: count)
                context.insert(record)
                record.repository = repository
            }
        }
    }
}

// MARK: - CommitActivityWeek

/// A single week of commit activity as returned by the GitHub Stats API.
///
/// The `days` array contains seven commit counts ordered Sunday through Saturday.
/// `week` is the Unix timestamp of the week's opening Sunday (midnight UTC).
struct CommitActivityWeek: Decodable, Sendable {

    /// Per-day commit counts for the week, indexed `[Sun, Mon, Tue, Wed, Thu, Fri, Sat]`.
    let days: [Int]

    /// The total number of commits during the week.
    let total: Int

    /// Unix timestamp of the week's opening Sunday (midnight UTC).
    let week: Int
}
