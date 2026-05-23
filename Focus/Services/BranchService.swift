import Foundation
import SwiftData

// MARK: - BranchService

/// Fetches and persists branch data for GitHub repositories.
///
/// `BranchService` performs a full-replace sync, removing all existing branch
/// records for a repository before inserting fresh results from the GitHub
/// GraphQL API. Silent failures leave any previously persisted data intact.
///
/// All network calls go through the injected ``GraphQLClient``.
struct BranchService: Sendable {

    // MARK: - Properties

    /// The GraphQL client used to execute branch queries.
    private let graphQL: GraphQLClient

    // MARK: - Init

    /// Creates a branch service backed by the given GraphQL client.
    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Fetch

    /// Fetches the 20 most recently updated branches for a repository from the GitHub GraphQL API.
    ///
    /// Branches whose `target` is not a `Commit` are silently excluded.
    /// Returns `nil` on any network or decoding error; does not write to SwiftData.
    func fetchBranches(owner: String, repo: String) async -> [BranchData]? {
        let variables: [String: any Sendable] = ["owner": owner, "name": repo]
        do {
            let response: BranchResponse = try await graphQL.execute(
                query: RepositoryQueries.repositoryBranches,
                variables: variables,
                responseType: BranchResponse.self
            )
            let defaultName = response.repository.defaultBranchRef?.name
            return response.repository.refs.nodes.compactMap { node in
                guard let committedDate = node.target?.committedDate else { return nil }
                return BranchData(
                    name: node.name,
                    isDefault: node.name == defaultName,
                    pushedAt: committedDate
                )
            }
        } catch {
            return nil
        }
    }

    // MARK: - Apply

    /// Persists fetched branches to SwiftData using a full-replace strategy.
    ///
    /// All existing `SavedBranch` records for the repository are deleted before the
    /// fresh records are inserted. Does nothing when `branches` is `nil` (preserving
    /// any existing data on transient fetch failures).
    @MainActor
    func applyBranches(_ branches: [BranchData]?, to repository: SavedRepository, in context: ModelContext) {
        guard let branches else { return }

        for existing in repository.branches ?? [] {
            existing.repository = nil
            context.delete(existing)
        }

        for data in branches {
            let branch = SavedBranch(name: data.name, isDefault: data.isDefault, pushedAt: data.pushedAt)
            branch.repository = repository
            context.insert(branch)
        }

        try? context.save()
    }

    // MARK: - Sync

    /// Fetches recent branches for a repository and replaces any existing records in SwiftData.
    ///
    /// Performs a full-replace sync: all existing branch records for `repository` are deleted
    /// before the fresh results are inserted. Errors from the network or SwiftData are silently
    /// discarded, leaving any previously persisted data intact.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - repo: The repository name.
    ///   - repository: The `SavedRepository` record whose branches will be replaced.
    ///   - context: The SwiftData model context used for persistence.
    @MainActor
    func syncBranches(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let branches = await fetchBranches(owner: owner, repo: repo)
        applyBranches(branches, to: repository, in: context)
    }
}

// MARK: - BranchData

/// Sendable transfer type carrying the fields needed to create a ``SavedBranch`` SwiftData record.
struct BranchData: Sendable {

    /// The branch name, e.g. `"main"` or `"feature/login-redesign"`.
    let name: String

    /// Whether this is the repository's default branch.
    let isDefault: Bool

    /// The date of the branch's most recent commit.
    let pushedAt: Date
}

// MARK: - API Response Types

/// The top-level GraphQL response for a repository branches query.
private struct BranchResponse: Decodable, Sendable {

    /// The repository returned by the query.
    let repository: BranchRepository
}

/// A repository node containing its default branch ref and refs connection.
private struct BranchRepository: Decodable, Sendable {

    /// The repository's default branch ref, or `nil` if none is set.
    let defaultBranchRef: DefaultBranchRef?

    /// The paginated connection of branch refs for this repository.
    let refs: RefConnection
}

/// The default branch ref containing only the branch name.
private struct DefaultBranchRef: Decodable, Sendable {

    /// The name of the default branch, e.g. `"main"`.
    let name: String
}

/// A GraphQL connection containing a list of ref nodes.
private struct RefConnection: Decodable, Sendable {

    /// The ref nodes returned by this connection.
    let nodes: [RefNode]
}

/// A single branch ref node from the GraphQL response.
private struct RefNode: Decodable, Sendable {

    /// The branch name.
    let name: String

    /// The commit the ref points to, or `nil` if the target is not a `Commit`.
    let target: CommitTarget?
}

/// A commit target extracted via the `... on Commit` inline fragment.
private struct CommitTarget: Decodable, Sendable {

    /// The date and time of the commit, or `nil` if the field was absent in the response.
    let committedDate: Date?
}
