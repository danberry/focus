import Foundation
import SwiftData

// MARK: - CodeownersService

/// Fetches and persists CODEOWNERS data for GitHub repositories.
///
/// `CodeownersService` downloads the CODEOWNERS file from one of the three
/// canonical locations (`CODEOWNERS`, `.github/CODEOWNERS`, `docs/CODEOWNERS`),
/// parses owner entries, and performs a full-replace sync into SwiftData.
///
/// All network calls go through the injected ``RESTClient``.
struct CodeownersService: Sendable {

    // MARK: - Properties

    /// The REST client used for GitHub API requests.
    private let rest: RESTClient

    // MARK: - Init

    /// Creates a new service wired to the given REST client.
    ///
    /// - Parameter rest: The REST client used to fetch CODEOWNERS file content.
    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Sync

    /// Fetches CODEOWNERS entries for a repository and replaces all persisted codeowners.
    ///
    /// Tries the three canonical CODEOWNERS file locations in order, using the first
    /// one that returns content. All previously persisted ``Codeowner`` objects for
    /// the repository are deleted before the new entries are inserted.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - repo: The repository name.
    ///   - repository: The ``SavedRepository`` whose codeowners to replace.
    ///   - context: The SwiftData model context used for persistence.
    @MainActor
    func syncCodeowners(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let entries = await fetchEntries(owner: owner, repo: repo)

        let existing = repository.codeowners
        for codeowner in existing {
            codeowner.repository = nil
            context.delete(codeowner)
        }

        for (pattern, handle) in entries {
            let codeowner = Codeowner(handle: handle, pathPattern: pattern)
            codeowner.repository = repository
            context.insert(codeowner)
        }

        try? context.save()
    }

    // MARK: - Private

    /// Tries each canonical CODEOWNERS path in order, returning parsed entries from the first that succeeds.
    private func fetchEntries(owner: String, repo: String) async -> [(pattern: String, handle: String)] {
        let candidates = [
            Endpoint.repoContents(owner: owner, repo: repo, path: "CODEOWNERS").path,
            Endpoint.repoContents(owner: owner, repo: repo, path: ".github/CODEOWNERS").path,
            Endpoint.repoContents(owner: owner, repo: repo, path: "docs/CODEOWNERS").path
        ]

        for path in candidates {
            if let content = await fetchFileContent(path: path) {
                return parseCodeowners(content)
            }
        }
        return []
    }

    /// Fetches and base64-decodes a file from `path`, returning `nil` on any error.
    private func fetchFileContent(path: String) async -> String? {
        do {
            let response: FileContentResponse = try await rest.get(path: path)
            guard response.encoding == "base64" else { return nil }
            let cleaned = response.content.filter { !$0.isWhitespace }
            guard let data = Data(base64Encoded: cleaned),
                  let text = String(data: data, encoding: .utf8) else { return nil }
            return text
        } catch {
            return nil
        }
    }

    /// Parses raw CODEOWNERS file text into `(pattern, handle)` pairs.
    private func parseCodeowners(_ content: String) -> [(pattern: String, handle: String)] {
        var result: [(String, String)] = []
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.components(separatedBy: .whitespaces)
            guard let first = parts.first else { continue }

            // If the first token is a handle (starts with @), there is no explicit
            // path pattern — treat it as a global catch-all ("*").
            let pattern: String
            let handleTokens: ArraySlice<String>
            if first.hasPrefix("@") {
                pattern = "*"
                handleTokens = parts[...]
            } else {
                pattern = first
                handleTokens = parts.dropFirst()
            }

            for handle in handleTokens where handle.hasPrefix("@") {
                result.append((pattern, handle))
            }
        }
        return result
    }
}

// MARK: - API Response Types

/// A GitHub REST API response for a repository file's encoded content.
private struct FileContentResponse: Decodable, Sendable {

    /// The file's content, encoded as specified by ``encoding``.
    let content: String

    /// The encoding format used for ``content``; GitHub always returns `"base64"`.
    let encoding: String
}
