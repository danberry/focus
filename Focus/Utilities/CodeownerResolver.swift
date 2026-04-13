import Foundation

// MARK: - CodeownerResolver

/// Resolves the set of owner handles responsible for a given file path,
/// applying GitHub's CODEOWNERS matching semantics.
///
/// Matching follows gitignore-style glob rules with a **last-rule-wins** policy:
/// when multiple patterns match the same path, the final pattern listed in the
/// CODEOWNERS file determines ownership. `CodeownerResolver` preserves this
/// semantic by scanning rules in file order and retaining only the handles
/// from the last matching rule.
///
/// Supported pattern syntax:
/// - A `nil` pattern matches every path (catch-all / legacy records).
/// - A pattern with no `/` matches the basename anywhere in the tree.
/// - A leading `/` anchors the pattern to the repository root.
/// - A trailing `/` matches any file under that directory at any depth.
/// - `*` matches any sequence of characters except `/`.
/// - `**` matches any sequence of characters including `/` (multi-segment wildcard).
/// - `?` matches a single non-separator character.
enum CodeownerResolver {

    // MARK: - Resolution

    /// Returns the owner handles responsible for `filePath` under the supplied CODEOWNERS rules.
    ///
    /// Scans `codeowners` in file order and applies last-rule-wins semantics:
    /// the handles from the final matching rule are returned. When multiple
    /// ``Codeowner`` rows share the same `pathPattern` (e.g., one pattern
    /// mapped to several handles), they are collapsed into a single logical
    /// rule before the last-match decision is made.
    ///
    /// - Parameters:
    ///   - filePath: The repository-relative path to evaluate (leading `/` is stripped if present).
    ///   - codeowners: All CODEOWNERS entries in file order, as produced by `syncCodeowners`.
    /// - Returns: The handle strings from the last matching rule, or an empty array if no rule matches.
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

    // MARK: - Matching

    /// Returns whether `pattern` matches `filePath` using gitignore-style glob rules.
    ///
    /// Pattern semantics applied in priority order:
    /// 1. A `nil` pattern matches everything (catch-all / legacy records).
    /// 2. A leading `/` anchors the match to the repository root; the slash is stripped before matching.
    /// 3. A trailing `/` (with or without a leading `/`) expands to a directory prefix match at any depth.
    /// 4. A pattern with no `/` is matched against the basename only, ignoring directory components.
    /// 5. A pattern with an internal `/` but no leading `/` is matched relative to the root.
    ///
    /// - Parameters:
    ///   - pattern: The CODEOWNERS path pattern, or `nil` for a catch-all entry.
    ///   - filePath: The repository-relative path to test (leading `/` is stripped if present).
    /// - Returns: `true` if the pattern matches `filePath`; `false` otherwise.
    // TODO: Add support for negation patterns (lines prefixed with `!`) — currently any negated entry is treated as a literal string beginning with `!`, which will never match a normal path and silently excludes ownership for that entry.
    // TODO: Add support for character-class patterns (`[abc]`, `[a-z]`) — unrecognised bracket expressions are passed through as literal characters and will silently fail to match paths that should be covered.
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

    /// Converts `pattern` and `path` to `Substring` slices and delegates to the
    /// recursive ``globMatchSlices(_:_:)`` engine.
    private static func globMatch(pattern: String, path: String) -> Bool {
        var p = pattern[pattern.startIndex...]
        var s = path[path.startIndex...]
        return globMatchSlices(&p, &s)
    }

    /// Recursively matches `pattern` against `path` using a consume-and-advance strategy.
    ///
    /// Both arguments are `inout Substring` slices so the algorithm advances in place
    /// without allocating new strings. The rules applied at each position:
    /// - `**` — consumes the double-star (and any following `/`), then tries to match the
    ///   remaining pattern against every suffix of `path` that starts after a `/`.
    /// - `*`  — consumes the single star, then tries every non-`/` prefix of `path`.
    /// - `?`  — matches exactly one character that is not `/`.
    /// - Literal — must equal the corresponding character in `path`.
    ///
    /// Returns `true` only when both `pattern` and `path` are fully consumed simultaneously.
    // TODO: Verify that `**` correctly matches zero segments (e.g. `**/foo` against `foo` at the root) — the branch advances by searching for the next `/`, so zero-segment matching relies on the empty-pattern early-return path; a missing test here could allow a regression to go undetected.
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
