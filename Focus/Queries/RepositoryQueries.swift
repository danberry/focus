// MARK: - RepositoryQueries

/// GraphQL query strings for fetching repository data from the GitHub v4 API.
///
/// Each property is a raw GraphQL query string intended to be sent via ``GraphQLClient``.
/// Variables are passed separately at the call site — they are not embedded in these strings.
///
/// All queries select a fixed field set. There is no mechanism for callers to
/// request additional fields without modifying the query strings directly.
enum RepositoryQueries {

    // MARK: - Listing

    /// Fetches the authenticated viewer's repositories, ordered by most recently updated.
    ///
    /// **Variables:**
    /// - `$first: Int!` — number of repositories to return per page (required).
    /// - `$after: String` — pagination cursor; omit or pass `null` for the first page.
    ///
    /// **Selected fields:** `id`, `name`, `nameWithOwner`, `description`, `visibility`,
    /// `isFork`, `stargazerCount`, `forkCount`, `primaryLanguage.name`, `url`,
    /// `updatedAt`, `owner.login`, `owner.avatarUrl`.
    ///
    /// **Pagination:** `pageInfo.endCursor` and `pageInfo.hasNextPage` are included
    /// so callers can walk all pages.
    ///
    /// - Note: Returns only repositories the viewer owns directly.
    // TODO: Include organization repositories — the viewer's org repos require separate queries or `affiliations` argument — users with large org membership will not see those repos here.
    static let viewerRepositories = """
        query($first: Int!, $after: String) {
            viewer {
                repositories(first: $first, after: $after, orderBy: {field: UPDATED_AT, direction: DESC}) {
                    nodes {
                        id
                        name
                        nameWithOwner
                        description
                        visibility
                        isFork
                        stargazerCount
                        forkCount
                        primaryLanguage { name }
                        url
                        updatedAt
                        owner { login avatarUrl }
                    }
                    pageInfo {
                        endCursor
                        hasNextPage
                    }
                }
            }
        }
        """

    /// Fetches a single repository by owner login and repository name.
    ///
    /// **Variables:**
    /// - `$owner: String!` — the repository owner's login (user or organization).
    /// - `$name: String!` — the repository name (not the full `owner/name` slug).
    ///
    /// **Selected fields:** `id`, `name`, `nameWithOwner`, `description`, `visibility`,
    /// `isFork`, `stargazerCount`, `forkCount`, `primaryLanguage.name`, `url`,
    /// `updatedAt`, `owner.login`, `owner.avatarUrl`.
    ///
    /// - Note: Returns `null` for the `repository` field (not an error) when the
    ///   repository does not exist or the viewer lacks read access.
    static let repository = """
        query($owner: String!, $name: String!) {
            repository(owner: $owner, name: $name) {
                id
                name
                nameWithOwner
                description
                visibility
                isFork
                stargazerCount
                forkCount
                primaryLanguage { name }
                url
                updatedAt
                owner { login avatarUrl }
            }
        }
        """

    // MARK: - Pull Requests

    /// Fetches open pull requests for a repository, ordered by creation date ascending.
    ///
    /// **Variables:**
    /// - `$owner: String!` — the repository owner's login (user or organization).
    /// - `$name: String!` — the repository name.
    ///
    /// **Selected fields:** `number`, `title`, `createdAt`, `author.login`, `url`.
    ///
    /// **Pagination:** not supported — this query fetches at most 100 pull requests
    /// in a single request with no cursor support.
    ///
    /// - Note: Only `OPEN` state pull requests are returned; draft and closed PRs are excluded.
    // TODO: Add pagination support — repositories with more than 100 open pull requests will return a silently truncated result set, with no indication that data was dropped.
    // TODO: Expose `states` as a variable — the hardcoded `OPEN` filter prevents reuse for closed or merged PR queries without duplicating this string.
    static let openPullRequests = """
        query($owner: String!, $name: String!) {
            repository(owner: $owner, name: $name) {
                pullRequests(states: [OPEN], first: 100, orderBy: {field: CREATED_AT, direction: ASC}) {
                    nodes {
                        number
                        title
                        createdAt
                        author { login }
                        url
                    }
                }
            }
        }
        """

    // MARK: - Releases

    /// Fetches the 10 most recently published releases for a repository.
    ///
    /// Draft releases (where `publishedAt` is `nil`) are excluded by the caller.
    /// The response includes all fields needed to populate a ``SavedRelease`` record.
    static let recentReleases = """
        query RepositoryRecentReleases($owner: String!, $name: String!) {
            repository(owner: $owner, name: $name) {
                releases(first: 10, orderBy: {field: CREATED_AT, direction: DESC}) {
                    nodes {
                        tagName
                        name
                        description
                        publishedAt
                        isPrerelease
                    }
                }
            }
        }
        """

    // MARK: - Branches

    /// Fetches the 20 most recently updated branches for a repository.
    ///
    /// The response includes the default branch name and each branch's last commit date.
    /// Branches with no `Commit` target (e.g. tags pointing to tree objects) are excluded
    /// by the caller via `compactMap`.
    static let repositoryBranches = """
        query RepositoryBranches($owner: String!, $name: String!) {
            repository(owner: $owner, name: $name) {
                defaultBranchRef {
                    name
                }
                refs(refPrefix: "refs/heads/", first: 20, orderBy: {field: TAG_COMMIT_DATE, direction: DESC}) {
                    nodes {
                        name
                        target {
                            ... on Commit {
                                committedDate
                            }
                        }
                    }
                }
            }
        }
        """

    // MARK: - Search

    /// Searches GitHub repositories using the GitHub search syntax.
    ///
    /// **Variables:**
    /// - `$query: String!` — a GitHub search query string (e.g. `"org:apple language:Swift"`).
    /// - `$first: Int!` — number of results to return per page (required).
    /// - `$after: String` — pagination cursor; omit or pass `null` for the first page.
    ///
    /// **Selected fields (per matching repository):** `id`, `name`, `nameWithOwner`,
    /// `description`, `visibility`, `isFork`, `stargazerCount`, `forkCount`,
    /// `primaryLanguage.name`, `url`, `updatedAt`, `owner.login`, `owner.avatarUrl`.
    ///
    /// **Pagination:** `pageInfo.endCursor` and `pageInfo.hasNextPage` are included
    /// so callers can walk all result pages.
    ///
    /// - Note: Results use `edges`/`node` rather than `nodes` due to GitHub's search
    ///   API shape; callers must unwrap accordingly.
    // TODO: Switch from edges/node to nodes — the current shape requires an extra unwrap layer at every call site; GitHub's search API supports nodes directly.
    static let searchRepositories = """
        query($query: String!, $first: Int!, $after: String) {
            search(query: $query, type: REPOSITORY, first: $first, after: $after) {
                edges {
                    node {
                        ... on Repository {
                            id
                            name
                            nameWithOwner
                            description
                            visibility
                            isFork
                            stargazerCount
                            forkCount
                            primaryLanguage { name }
                            url
                            updatedAt
                            owner { login avatarUrl }
                        }
                    }
                }
                pageInfo {
                    endCursor
                    hasNextPage
                }
            }
        }
        """
}
