import Foundation
import SwiftData

// MARK: - PullRequestService

struct PullRequestService: Sendable {
    private let graphQL: GraphQLClient

    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Sync

    @MainActor
    func syncOpenPullRequests(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let variables: [String: any Sendable] = [
            "owner": owner,
            "name": repo
        ]

        do {
            let response: PRResponse = try await graphQL.execute(
                query: RepositoryQueries.openPullRequests,
                variables: variables,
                responseType: PRResponse.self
            )

            // Full-replace sync: remove existing open PR records for this repository.
            for existing in repository.openPullRequests {
                existing.repository = nil
                context.delete(existing)
            }

            let iso = ISO8601DateFormatter()

            for node in response.repository.pullRequests.nodes {
                let createdAt = iso.date(from: node.createdAt) ?? Date()
                let pr = OpenPullRequest(
                    number: node.number,
                    title: node.title,
                    createdAt: createdAt,
                    authorLogin: node.author?.login ?? "",
                    url: node.url
                )
                pr.repository = repository
                context.insert(pr)
            }

            try? context.save()
        } catch {
            // Silently fail — keeps any existing data intact
        }
    }
}

// MARK: - Response Types

private struct PRResponse: Decodable, Sendable {
    let repository: PRRepository

    struct PRRepository: Decodable, Sendable {
        let pullRequests: PRConnection
    }

    struct PRConnection: Decodable, Sendable {
        let nodes: [PRNode]
    }

    struct PRNode: Decodable, Sendable {
        let number: Int
        let title: String
        let createdAt: String
        let author: PRAuthor?
        let url: String
    }

    struct PRAuthor: Decodable, Sendable {
        let login: String
    }
}
