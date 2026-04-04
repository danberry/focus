// MARK: - UserQueries

enum UserQueries {
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
