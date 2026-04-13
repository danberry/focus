import Testing
@testable import Focus

// MARK: - CodeownerResolverTests

/// Tests for `CodeownerResolver`.
@Suite("CodeownerResolver Tests")
struct CodeownerResolverTests {

    // MARK: - matches(pattern:filePath:)

    /// Verifies that a `nil` pattern matches any file path, including the empty string.
    @Test func nilPatternMatchesEverything() {
        #expect(CodeownerResolver.matches(pattern: nil, filePath: "any/file.swift"))
        #expect(CodeownerResolver.matches(pattern: nil, filePath: ""))
    }

    /// Verifies that a `*` wildcard pattern matches any file path.
    @Test func wildcardMatchesAnyFile() {
        #expect(CodeownerResolver.matches(pattern: "*", filePath: "README.md"))
        #expect(CodeownerResolver.matches(pattern: "*", filePath: "src/main.swift"))
    }

    /// Verifies that `**/*.swift` matches `.swift` files at any directory depth.
    @Test func doubleWildcardMatchesAcrossDirectories() {
        #expect(CodeownerResolver.matches(pattern: "**/*.swift", filePath: "src/foo/bar.swift"))
        #expect(CodeownerResolver.matches(pattern: "**/*.swift", filePath: "bar.swift"))
    }

    /// Verifies that a no-slash extension pattern like `*.swift` matches the filename at any path depth.
    @Test func extensionPatternMatchesFilenameAnywhere() {
        // No slash in pattern → filename match anywhere in the tree
        #expect(CodeownerResolver.matches(pattern: "*.swift", filePath: "Sources/App/main.swift"))
        #expect(CodeownerResolver.matches(pattern: "*.swift", filePath: "main.swift"))
        #expect(!CodeownerResolver.matches(pattern: "*.swift", filePath: "main.rs"))
    }

    /// Verifies that a bare filename pattern matches files with that name anywhere in the tree.
    @Test func specificFilenamePatternMatchesExactBasename() {
        #expect(CodeownerResolver.matches(pattern: "package.json", filePath: "sub/package.json"))
        #expect(CodeownerResolver.matches(pattern: "package.json", filePath: "package.json"))
        #expect(!CodeownerResolver.matches(pattern: "package.json", filePath: "sub/other.json"))
    }

    /// Verifies that a leading-slash pattern anchors the match to the repository root.
    @Test func anchoredPatternMatchesFromRoot() {
        #expect(CodeownerResolver.matches(pattern: "/docs/", filePath: "docs/guide.md"))
        #expect(!CodeownerResolver.matches(pattern: "/docs/", filePath: "src/docs/guide.md"))
    }

    /// Verifies that a trailing-slash pattern matches all files within that directory subtree.
    @Test func directoryPatternMatchesFilesUnder() {
        #expect(CodeownerResolver.matches(pattern: "src/", filePath: "src/main.swift"))
        #expect(CodeownerResolver.matches(pattern: "src/", filePath: "src/nested/deep.swift"))
        #expect(!CodeownerResolver.matches(pattern: "src/", filePath: "lib/other.swift"))
    }

    /// Verifies that a leading-slash file pattern matches only the root-level file, not nested copies.
    @Test func anchoredFilePatternMatchesOnlyAtRoot() {
        #expect(CodeownerResolver.matches(pattern: "/package.json", filePath: "package.json"))
        #expect(!CodeownerResolver.matches(pattern: "/package.json", filePath: "sub/package.json"))
    }

    // MARK: - resolve(filePath:codeowners:)

    /// Verifies that an empty codeowners list produces no resolved owners.
    @Test func emptyCodeownersReturnsEmpty() {
        let result = CodeownerResolver.resolve(filePath: "any/file.swift", codeowners: [])
        #expect(result.isEmpty)
    }

    /// Verifies that no owners are returned when no pattern matches the file path.
    @Test func noMatchReturnsEmpty() {
        let owner = Codeowner(handle: "@alice", pathPattern: "*.go")
        let result = CodeownerResolver.resolve(filePath: "main.swift", codeowners: [owner])
        #expect(result.isEmpty)
    }

    /// Verifies that a matching pattern returns its associated owner handle.
    @Test func singleMatchReturnsHandle() {
        let owner = Codeowner(handle: "@alice", pathPattern: "*.swift")
        let result = CodeownerResolver.resolve(filePath: "main.swift", codeowners: [owner])
        #expect(result == ["@alice"])
    }

    /// Verifies that when multiple patterns match, only the last matching rule's owners are returned.
    @Test func lastRuleWins() {
        // Two patterns both match; the last one should win
        let first = Codeowner(handle: "@alice", pathPattern: "*")
        let second = Codeowner(handle: "@bob", pathPattern: "*.swift")
        let result = CodeownerResolver.resolve(filePath: "main.swift", codeowners: [first, second])
        #expect(result == ["@bob"])
        #expect(!result.contains("@alice"))
    }

    /// Verifies that multiple owners sharing the same pattern are all returned.
    @Test func multipleHandlesOnSamePattern() {
        let alice = Codeowner(handle: "@alice", pathPattern: "*.swift")
        let bob = Codeowner(handle: "@bob", pathPattern: "*.swift")
        let result = CodeownerResolver.resolve(filePath: "app.swift", codeowners: [alice, bob])
        #expect(result.sorted() == ["@alice", "@bob"])
    }

    /// Verifies that a later non-matching rule does not clear owners set by a previous matching rule.
    @Test func laterNonMatchingRuleDoesNotClearPreviousMatch() {
        let swift = Codeowner(handle: "@alice", pathPattern: "*.swift")
        let go = Codeowner(handle: "@bob", pathPattern: "*.go")
        let result = CodeownerResolver.resolve(filePath: "app.swift", codeowners: [swift, go])
        #expect(result == ["@alice"])
    }

    /// Verifies that a specific pattern following a catch-all overrides the catch-all owners.
    @Test func catchAllFollowedBySpecificPattern() {
        let everyone = Codeowner(handle: "@team", pathPattern: "*")
        let docs = Codeowner(handle: "@docs-team", pathPattern: "docs/")
        let result = CodeownerResolver.resolve(filePath: "docs/guide.md", codeowners: [everyone, docs])
        #expect(result == ["@docs-team"])
    }

    /// Verifies that a `nil` catch-all pattern is overridden by a more specific pattern appearing later.
    @Test func nilPatternCatchAllIsOverriddenBySpecificPattern() {
        let catchAll = Codeowner(handle: "@everyone", pathPattern: nil)
        let specific = Codeowner(handle: "@alice", pathPattern: "*.swift")
        let result = CodeownerResolver.resolve(filePath: "main.swift", codeowners: [catchAll, specific])
        #expect(result == ["@alice"])
    }
}
