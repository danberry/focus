import Foundation
import SwiftData

// MARK: - SavedRelease

/// A GitHub release published on a watched repository.
///
/// `SavedRelease` is a child entity in the SwiftData graph. It is
/// cascade-deleted when its parent ``SavedRepository`` is removed.
@Model
final class SavedRelease {

    // MARK: - Properties

    /// The release tag name, e.g. `"v2.14.0"`.
    var tag: String = ""

    /// The release title, which may differ from the tag.
    var name: String = ""

    /// The release notes body in Markdown.
    var body: String = ""

    /// The date and time the release was published.
    var publishedAt: Date = Date()

    /// Whether GitHub flags this release as a prerelease.
    var isPrerelease: Bool = false

    // MARK: - Init

    /// Creates a new saved release record.
    ///
    /// - Parameters:
    ///   - tag: The release tag name, e.g. `"v2.14.0"`.
    ///   - name: The release title, which may differ from the tag.
    ///   - body: The release notes body in Markdown.
    ///   - publishedAt: The date and time the release was published.
    ///   - isPrerelease: Whether GitHub flags this release as a prerelease.
    init(
        tag: String,
        name: String,
        body: String,
        publishedAt: Date,
        isPrerelease: Bool
    ) {
        self.tag = tag
        self.name = name
        self.body = body
        self.publishedAt = publishedAt
        self.isPrerelease = isPrerelease
    }

    // MARK: - Relationships

    /// The repository this release belongs to.
    ///
    /// Cascade-deleted when the parent repository is removed. Inverse of ``SavedRepository/releases``.
    @Relationship var repository: SavedRepository?
}
