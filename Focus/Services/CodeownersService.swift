import Foundation
import SwiftData

// MARK: - CodeownersService

struct CodeownersService: Sendable {
    private let rest: RESTClient

    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Sync

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

    private func fetchFileContent(path: String) async -> String? {
        do {
            let response: FileContentResponse = try await rest.get(path: path)
            guard response.encoding == "base64" else {
                print("[CodeownersService] Unexpected encoding '\(response.encoding)' at \(path)")
                return nil
            }
            let cleaned = response.content.filter { !$0.isWhitespace }
            guard let data = Data(base64Encoded: cleaned) else {
                print("[CodeownersService] Base64 decode failed at \(path)")
                return nil
            }
            guard let text = String(data: data, encoding: .utf8) else {
                print("[CodeownersService] UTF-8 decode failed at \(path)")
                return nil
            }
            print("[CodeownersService] Loaded \(path) — \(text.components(separatedBy: .newlines).filter { !$0.isEmpty && !$0.hasPrefix("#") }.count) rule(s)")
            return text
        } catch {
            print("[CodeownersService] Fetch failed at \(path): \(error)")
            return nil
        }
    }

    private func parseCodeowners(_ content: String) -> [(pattern: String, handle: String)] {
        var result: [(String, String)] = []
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.components(separatedBy: .whitespaces)
            guard let pattern = parts.first else { continue }
            for handle in parts.dropFirst() where handle.hasPrefix("@") {
                result.append((pattern, handle))
            }
        }
        return result
    }
}

// MARK: - FileContentResponse

private struct FileContentResponse: Decodable, Sendable {
    let content: String
    let encoding: String
}
