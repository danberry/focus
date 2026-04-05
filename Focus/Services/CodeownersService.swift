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
        let handles = await fetchHandles(owner: owner, repo: repo)

        let existing = repository.codeowners
        for codeowner in existing {
            codeowner.repository = nil
            context.delete(codeowner)
        }

        for handle in handles {
            let codeowner = Codeowner(handle: handle)
            codeowner.repository = repository
            context.insert(codeowner)
        }
    }

    // MARK: - Private

    private func fetchHandles(owner: String, repo: String) async -> [String] {
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
            guard response.encoding == "base64" else { return nil }
            let cleaned = response.content.filter { !$0.isWhitespace }
            guard let data = Data(base64Encoded: cleaned),
                  let text = String(data: data, encoding: .utf8) else { return nil }
            return text
        } catch {
            return nil
        }
    }

    private func parseCodeowners(_ content: String) -> [String] {
        var seen = Set<String>()
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.components(separatedBy: .whitespaces)
            for part in parts.dropFirst() where part.hasPrefix("@") {
                seen.insert(part)
            }
        }
        return seen.sorted()
    }
}

// MARK: - FileContentResponse

private struct FileContentResponse: Decodable, Sendable {
    let content: String
    let encoding: String
}
