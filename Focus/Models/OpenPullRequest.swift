import Foundation
import SwiftData

// MARK: - OpenPullRequest

/// A GitHub pull request that is currently open on a watched repository.
///
/// `OpenPullRequest` is a child entity in the SwiftData graph. It is
/// cascade-deleted when its parent ``SavedRepository`` is removed.
@Model
final class OpenPullRequest {

    // MARK: - Properties

    /// The pull request number within the repository.
    var number: Int

    /// The pull request title.
    var title: String

    /// The date and time the pull request was opened.
    var createdAt: Date

    /// The GitHub login of the pull request author.
    var authorLogin: String

    /// The URL of the pull request on GitHub.
    var url: String

    // MARK: - Init

    /// Creates a new open pull request record.
    ///
    /// - Parameters:
    ///   - number: The pull request number within the repository.
    ///   - title: The pull request title.
    ///   - createdAt: The date and time the pull request was opened.
    ///   - authorLogin: The GitHub login of the pull request author.
    ///   - url: The URL of the pull request on GitHub.
    init(
        number: Int,
        title: String,
        createdAt: Date,
        authorLogin: String,
        url: String
    ) {
        self.number = number
        self.title = title
        self.createdAt = createdAt
        self.authorLogin = authorLogin
        self.url = url
    }

    // MARK: - Relationships

    /// The repository this pull request belongs to.
    ///
    /// Cascade-deleted when the parent repository is removed. Inverse of ``SavedRepository/openPullRequests``.
    var repository: SavedRepository?
}
