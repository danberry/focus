import Foundation
import SwiftData

// MARK: - ReleaseService

/// Fetches and persists release data for GitHub repositories.
///
/// `ReleaseService` performs a full-replace sync, removing all existing release
/// records for a repository before inserting fresh results from the GitHub
/// GraphQL API. Silent failures leave any previously persisted data intact.
///
/// All network calls go through the injected ``GraphQLClient``.
struct ReleaseService: Sendable {

    // MARK: - Properties

    /// The GraphQL client used to execute release queries.
    private let graphQL: GraphQLClient

    // MARK: - Init

    /// Creates a release service backed by the given GraphQL client.
    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Fetch (non-isolated, Sendable result)

    /// Fetches the 10 most recent releases for a repository from the GitHub GraphQL API.
    ///
    /// Draft releases — those with a `nil` `publishedAt` — are filtered out before returning.
    /// Returns `nil` on any network or decoding error; does not write to SwiftData.
    func fetchReleases(owner: String, repo: String) async -> [ReleaseData]? {
        let variables: [String: any Sendable] = ["owner": owner, "name": repo]
        do {
            let response: ReleaseResponse = try await graphQL.execute(
                query: RepositoryQueries.recentReleases,
                variables: variables,
                responseType: ReleaseResponse.self
            )
            return response.repository.releases.nodes.compactMap { node in
                guard let publishedAt = node.publishedAt else { return nil }
                return ReleaseData(
                    tag: node.tagName,
                    name: node.name ?? "",
                    body: node.releaseDescription ?? "",
                    publishedAt: publishedAt,
                    isPrerelease: node.isPrerelease
                )
            }
        } catch {
            return nil
        }
    }

    // MARK: - Apply (@MainActor, writes to SwiftData)

    /// Persists fetched releases to SwiftData using a full-replace strategy.
    ///
    /// All existing `SavedRelease` records for the repository are deleted before the
    /// fresh records are inserted. Does nothing when `releases` is `nil` (preserving
    /// any existing data on transient fetch failures).
    @MainActor
    func applyReleases(_ releases: [ReleaseData]?, to repository: SavedRepository, in context: ModelContext) {
        guard let releases else { return }

        for existing in repository.releases ?? [] {
            existing.repository = nil
            context.delete(existing)
        }

        for data in releases {
            let release = SavedRelease(
                tag: data.tag,
                name: data.name,
                body: data.body,
                publishedAt: data.publishedAt,
                isPrerelease: data.isPrerelease
            )
            release.repository = repository
            context.insert(release)
        }

        try? context.save()
    }

    // MARK: - Sync (fetch + apply, used by tests and legacy call sites)

    /// Fetches recent releases for a repository and replaces any existing records in SwiftData.
    ///
    /// Performs a full-replace sync: all existing release records for `repository` are deleted
    /// before the fresh results are inserted. Errors from the network or SwiftData are silently
    /// discarded, leaving any previously persisted data intact.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - repo: The repository name.
    ///   - repository: The `SavedRepository` record whose releases will be replaced.
    ///   - context: The SwiftData model context used for persistence.
    @MainActor
    func syncReleases(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let releases = await fetchReleases(owner: owner, repo: repo)
        applyReleases(releases, to: repository, in: context)
    }
}

// MARK: - ReleaseData

/// Sendable transfer type carrying the fields needed to create a ``SavedRelease`` SwiftData record.
struct ReleaseData: Sendable {

    /// The release tag name, e.g. `"v2.14.0"`.
    let tag: String

    /// The release title; may be empty if GitHub returned `nil`.
    let name: String

    /// The release notes body in Markdown; may be empty if GitHub returned `nil`.
    let body: String

    /// The date and time the release was published.
    let publishedAt: Date

    /// Whether GitHub flags this release as a prerelease.
    let isPrerelease: Bool
}

// MARK: - API Response Types

/// The top-level GraphQL response for a recent-releases query.
private struct ReleaseResponse: Decodable, Sendable {

    /// The repository returned by the query.
    let repository: ReleaseRepository
}

/// A repository node containing its release connection.
private struct ReleaseRepository: Decodable, Sendable {

    /// The paginated connection of releases for this repository.
    let releases: ReleaseConnection
}

/// A GraphQL connection containing a list of release nodes.
private struct ReleaseConnection: Decodable, Sendable {

    /// The release nodes returned by this connection.
    let nodes: [ReleaseNode]
}

/// A single release node from the GraphQL response.
private struct ReleaseNode: Decodable, Sendable {

    /// The release tag name, e.g. `"v2.14.0"`.
    let tagName: String

    /// The release title, which may be `nil` when GitHub has no title set.
    let name: String?

    /// The release notes body in Markdown, mapped from the GraphQL `description` field.
    ///
    /// Renamed at the Swift level to avoid colliding with `CustomStringConvertible.description`.
    let releaseDescription: String?

    /// The publish timestamp; `nil` for draft releases.
    let publishedAt: Date?

    /// Whether GitHub flags this release as a prerelease.
    let isPrerelease: Bool

    /// Coding keys mapping the JSON `description` field to ``releaseDescription``.
    private enum CodingKeys: String, CodingKey {
        case tagName
        case name
        case releaseDescription = "description"
        case publishedAt
        case isPrerelease
    }
}
