import Foundation

// MARK: - CodeownerEmailService

/// Resolves GitHub CODEOWNERS handles to user logins and email addresses.
///
/// `CodeownerEmailService` expands both individual handles (`@username`) and team handles
/// (`@org/team-slug`) by fetching team membership via the GitHub REST API. All resolutions
/// run concurrently. Network errors are silently discarded.
///
/// All network calls go through the injected ``RESTClient``.
struct CodeownerEmailService: Sendable {

    // MARK: - Properties

    /// The REST client used for all GitHub API requests.
    private let rest: RESTClient

    // MARK: - Init

    /// Creates a new service backed by the given REST client.
    ///
    /// - Parameter rest: The client used for GitHub REST API calls.
    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Login Resolution

    /// Resolves CODEOWNERS handles to deduplicated, sorted GitHub user logins.
    ///
    /// Individual handles (`@username`) resolve directly to their login. Team handles
    /// (`@org/team-slug`) are expanded via `GET /orgs/{org}/teams/{slug}/members`.
    /// Network errors for any handle are silently discarded.
    ///
    /// - Parameter handles: CODEOWNERS-formatted owner handles, with or without a leading `@`.
    /// - Returns: A sorted, deduplicated list of GitHub user logins.
    func resolveLogins(handles: [String]) async -> [String] {
        var logins = Set<String>()
        await withTaskGroup(of: [String].self) { group in
            for handle in handles {
                group.addTask {
                    await self.resolveHandleToLogins(handle)
                }
            }
            for await resolved in group {
                logins.formUnion(resolved)
            }
        }
        return logins.sorted()
    }

    // MARK: - Email Resolution

    /// Resolves CODEOWNERS handles to deduplicated, sorted email addresses.
    ///
    /// Individual handles (`@username`) are resolved via `GET /users/{login}`. Team handles
    /// (`@org/team-slug`) are expanded to their member list, then each member's email is fetched
    /// individually. Empty and missing email addresses are excluded. Network errors are silently discarded.
    ///
    /// - Parameters:
    ///   - handles: CODEOWNERS-formatted owner handles, with or without a leading `@`.
    ///   - organization: The owning organization context for team membership lookups.
    /// - Returns: A sorted, deduplicated list of non-empty email addresses.
    func resolveEmails(handles: [String], organization: String) async -> [String] {
        var emails = Set<String>()
        await withTaskGroup(of: [String].self) { group in
            for handle in handles {
                group.addTask {
                    await self.resolveHandle(handle, organization: organization)
                }
            }
            for await resolved in group {
                emails.formUnion(resolved)
            }
        }
        return emails.sorted()
    }

    // MARK: - Private

    /// Resolves a single handle to one or more GitHub user logins.
    ///
    /// Returns `[login]` for individual handles and expands team handles via ``resolveTeamToLogins(_:)``.
    private func resolveHandleToLogins(_ handle: String) async -> [String] {
        let login = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
        if login.contains("/") {
            return await resolveTeamToLogins(login)
        } else {
            return [login]
        }
    }

    /// Fetches all member logins for a team specified as `org/team-slug`.
    ///
    /// Returns an empty array on any network or decoding error.
    private func resolveTeamToLogins(_ orgAndSlug: String) async -> [String] {
        let parts = orgAndSlug.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { return [] }
        let org = String(parts[0])
        let slug = String(parts[1])
        do {
            let members: [RESTUser] = try await rest.get(
                path: Endpoint.teamMembers(org: org, teamSlug: slug).path
            )
            return members.map { $0.login }
        } catch {
            return []
        }
    }

    /// Resolves a single handle to one or more email addresses.
    ///
    /// Delegates individual handles to ``fetchUserEmail(login:)`` and team handles to ``resolveTeam(_:organization:)``.
    private func resolveHandle(_ handle: String, organization: String) async -> [String] {
        let login = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
        if login.contains("/") {
            return await resolveTeam(login, organization: organization)
        } else {
            if let email = await fetchUserEmail(login: login) {
                return [email]
            }
            return []
        }
    }

    /// Fetches email addresses for all members of a team specified as `org/team-slug`.
    ///
    /// Member email lookups run concurrently. Returns an empty array on any team membership error.
    private func resolveTeam(_ orgAndSlug: String, organization: String) async -> [String] {
        let parts = orgAndSlug.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { return [] }
        let org = String(parts[0])
        let slug = String(parts[1])

        let members: [RESTUser]
        do {
            members = try await rest.get(path: Endpoint.teamMembers(org: org, teamSlug: slug).path)
        } catch {
            return []
        }

        var emails: [String] = []
        await withTaskGroup(of: String?.self) { group in
            for member in members {
                group.addTask {
                    await self.fetchUserEmail(login: member.login)
                }
            }
            for await email in group {
                if let email { emails.append(email) }
            }
        }
        return emails
    }

    /// Fetches the public email address for a GitHub user.
    ///
    /// Returns `nil` on any network error or when the profile email is empty.
    private func fetchUserEmail(login: String) async -> String? {
        do {
            let profile: UserProfileResponse = try await rest.get(
                path: Endpoint.userProfile(login: login).path
            )
            return profile.email.flatMap { $0.isEmpty ? nil : $0 }
        } catch {
            return nil
        }
    }
}

// MARK: - API Response Types

/// A GitHub REST API user profile response.
private struct UserProfileResponse: Decodable, Sendable {
    /// The user's GitHub login handle.
    let login: String
    /// The user's public email address, or `nil` if not set on their profile.
    let email: String?
}
