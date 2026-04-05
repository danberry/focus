import Foundation

// MARK: - CodeownerResolver

/// Resolves which CODEOWNERS handles are responsible for a given file path,
/// following GitHub's gitignore-style matching rules (last matching rule wins).
enum CodeownerResolver {

    /// Returns the handles that own `filePath` per CODEOWNERS rules.
    /// The last matching entry in the list wins (GitHub semantics).
    /// Codeowners must be passed in file order (insertion order from `syncCodeowners`).
    static func resolve(filePath: String, codeowners: [Codeowner]) -> [String] {
        var lastMatch: [String] = []
        var lastMatchedPattern: String? = nil
        for codeowner in codeowners {
            guard matches(pattern: codeowner.pathPattern, filePath: filePath) else { continue }
            if codeowner.pathPattern != lastMatchedPattern {
                lastMatchedPattern = codeowner.pathPattern
                lastMatch = []
            }
            lastMatch.append(codeowner.handle)
        }
        return lastMatch
    }

    /// Gitignore-style glob matching of a CODEOWNERS pattern against a file path.
    /// - A `nil` pattern matches everything (catch-all / legacy records).
    /// - A pattern without `/` (other than a trailing one) matches a filename anywhere.
    /// - A leading `/` anchors the match to the repository root.
    /// - A trailing `/` matches any file under that directory.
    /// - `*` matches any sequence of characters except `/`.
    /// - `**` matches any sequence of characters including `/`.
    static func matches(pattern: String?, filePath: String) -> Bool {
        guard let pattern else { return true }

        let path = filePath.hasPrefix("/") ? String(filePath.dropFirst()) : filePath

        // Leading slash: always anchored to the repository root.
        if pattern.hasPrefix("/") {
            let anchored = String(pattern.dropFirst())
            if anchored.hasSuffix("/") {
                return globMatch(pattern: anchored + "**", path: path)
            }
            return globMatch(pattern: anchored, path: path)
        }

        // Trailing slash (no leading slash): directory match at any level.
        if pattern.hasSuffix("/") {
            return globMatch(pattern: pattern + "**", path: path) ||
                   globMatch(pattern: "**/" + pattern + "**", path: path)
        }

        // Pattern with no slash at all: filename match anywhere in the tree.
        if !pattern.contains("/") {
            let basename = (path as NSString).lastPathComponent
            return globMatch(pattern: pattern, path: basename)
        }

        // Pattern with an internal slash but no leading slash: match relative to root.
        return globMatch(pattern: pattern, path: path)
    }

    // MARK: - Private

    /// Recursive glob match supporting `*` (non-separator wildcard) and `**` (multi-segment wildcard).
    private static func globMatch(pattern: String, path: String) -> Bool {
        var p = pattern[pattern.startIndex...]
        var s = path[path.startIndex...]
        return globMatchSlices(&p, &s)
    }

    private static func globMatchSlices(
        _ pattern: inout Substring,
        _ path: inout Substring
    ) -> Bool {
        while !pattern.isEmpty {
            if pattern.hasPrefix("**") {
                // Consume the ** and any adjacent slashes
                pattern = pattern.dropFirst(2)
                if pattern.hasPrefix("/") { pattern = pattern.dropFirst() }

                // ** matches zero or more path segments
                if pattern.isEmpty { return true }
                var remaining = path
                while true {
                    var p2 = pattern
                    var s2 = remaining
                    if globMatchSlices(&p2, &s2) { return true }
                    // Advance past next slash
                    guard let slash = remaining.firstIndex(of: "/") else { break }
                    remaining = remaining[remaining.index(after: slash)...]
                }
                return false
            } else if pattern.first == "*" {
                pattern = pattern.dropFirst()
                // * matches any sequence of non-slash characters
                var remaining = path
                while true {
                    var p2 = pattern
                    var s2 = remaining
                    if globMatchSlices(&p2, &s2) { return true }
                    if remaining.isEmpty || remaining.first == "/" { break }
                    remaining = remaining.dropFirst()
                }
                return false
            } else if pattern.first == "?" {
                guard !path.isEmpty, path.first != "/" else { return false }
                pattern = pattern.dropFirst()
                path = path.dropFirst()
            } else {
                guard pattern.first == path.first else { return false }
                pattern = pattern.dropFirst()
                path = path.dropFirst()
            }
        }
        return path.isEmpty
    }
}
