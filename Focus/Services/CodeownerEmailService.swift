import Foundation

// MARK: - CodeownerEmailService

struct CodeownerEmailService: Sendable {
    private let rest: RESTClient

    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Email Resolution

    /// Resolves email addresses for the given CODEOWNERS handles.
    /// Individual handles (`@username`) → `GET /users/{login}`
    /// Team handles (`@org/team-slug`) → expand members, then look up each member's email.
    /// Returns deduplicated, non-empty email strings. Network errors are silently ignored.
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

// MARK: - UserProfileResponse

private struct UserProfileResponse: Decodable, Sendable {
    let login: String
    let email: String?
}
