// MARK: - UserQueries

/// A namespace for GitHub GraphQL query strings related to users.
///
/// Each static property is a raw GraphQL query string passed directly to
/// ``GraphQLClient``. Variable substitution is performed by the client.
enum UserQueries {

    // MARK: - Properties

    /// Fetches the authenticated user's profile fields.
    ///
    /// Uses the `viewer` root field, which always resolves to the token owner.
    /// No variables required.
    ///
    // TODO: Include private repository count — `publicRepos` only reflects public visibility, undercounting for users with private repos.
    static let viewer = """
        query {
            viewer {
                id
                login
                name
                avatarUrl
                bio
                company
                location
                email
                publicRepos: repositories(privacy: PUBLIC) { totalCount }
                followers { totalCount }
                following { totalCount }
            }
        }
        """

    /// Fetches a specific user's profile fields by login.
    ///
    /// - Variable `login`: The GitHub username to look up.
    ///
    // TODO: Handle null user gracefully — GitHub returns `null` for the `user` field when the login does not exist, which will cause decoding to fail unless the caller's model marks it optional.
    static let user = """
        query($login: String!) {
            user(login: $login) {
                id
                login
                name
                avatarUrl
                bio
                company
                location
                email
                publicRepos: repositories(privacy: PUBLIC) { totalCount }
                followers { totalCount }
                following { totalCount }
            }
        }
        """

    /// Searches GitHub users by query string with cursor-based pagination.
    ///
    /// - Variable `query`: The search string; supports GitHub search syntax.
    /// - Variable `first`: Maximum number of results to return per page.
    /// - Variable `after`: Pagination cursor, or `nil` for the first page.
    ///
    // TODO: Results exclude organizations — the `USER` search type omits orgs that match the query. Add an Organization inline fragment if org results are needed.
    static let searchUsers = """
        query($query: String!, $first: Int!, $after: String) {
            search(query: $query, type: USER, first: $first, after: $after) {
                edges {
                    node {
                        ... on User {
                            id
                            login
                            name
                            avatarUrl
                            bio
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
