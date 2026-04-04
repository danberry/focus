// MARK: - RepositoryQueries

enum RepositoryQueries {
    static let viewerRepositories = """
        query($first: Int!, $after: String) {
            viewer {
                repositories(first: $first, after: $after, orderBy: {field: UPDATED_AT, direction: DESC}) {
                    nodes {
                        id
                        name
                        nameWithOwner
                        description
                        isPrivate
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

    static let repository = """
        query($owner: String!, $name: String!) {
            repository(owner: $owner, name: $name) {
                id
                name
                nameWithOwner
                description
                isPrivate
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
                            isPrivate
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
