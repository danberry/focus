import Foundation

// MARK: - MergedPR

/// A pull request that has been merged into a repository.
struct MergedPR: Identifiable, Sendable {

    // MARK: - Properties

    /// The pull request number within its repository.
    let number: Int

    /// The pull request title.
    let title: String

    /// The date and time the pull request was opened.
    let createdAt: Date

    /// The date and time the pull request was merged.
    let mergedAt: Date

    /// The GitHub login of the user who authored the pull request.
    let authorLogin: String

    /// The URL of the pull request on GitHub.
    let url: String

    /// The repository name in `owner/repo` format.
    let repoNameWithOwner: String

    /// The number of lines added by this pull request.
    let additions: Int

    /// The number of lines deleted by this pull request.
    let deletions: Int

    // MARK: - Computed

    /// A stable identifier combining the repository name and pull request number.
    var id: String { "\(repoNameWithOwner)#\(number)" }

    /// Total lines changed by this pull request (additions + deletions).
    var linesChanged: Int { additions + deletions }
}
