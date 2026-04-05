import Testing
@testable import Focus

// MARK: - CodeownerResolverTests

@Suite("CodeownerResolver Tests")
struct CodeownerResolverTests {

    // MARK: - matches(pattern:filePath:)

    @Test func nilPatternMatchesEverything() {
        #expect(CodeownerResolver.matches(pattern: nil, filePath: "any/file.swift"))
        #expect(CodeownerResolver.matches(pattern: nil, filePath: ""))
    }

    @Test func wildcardMatchesAnyFile() {
        #expect(CodeownerResolver.matches(pattern: "*", filePath: "README.md"))
        #expect(CodeownerResolver.matches(pattern: "*", filePath: "src/main.swift"))
    }

    @Test func doubleWildcardMatchesAcrossDirectories() {
        #expect(CodeownerResolver.matches(pattern: "**/*.swift", filePath: "src/foo/bar.swift"))
        #expect(CodeownerResolver.matches(pattern: "**/*.swift", filePath: "bar.swift"))
    }

    @Test func extensionPatternMatchesFilenameAnywhere() {
        // No slash in pattern → filename match anywhere in the tree
        #expect(CodeownerResolver.matches(pattern: "*.swift", filePath: "Sources/App/main.swift"))
        #expect(CodeownerResolver.matches(pattern: "*.swift", filePath: "main.swift"))
        #expect(!CodeownerResolver.matches(pattern: "*.swift", filePath: "main.rs"))
    }

    @Test func specificFilenamePatternMatchesExactBasename() {
        #expect(CodeownerResolver.matches(pattern: "package.json", filePath: "sub/package.json"))
        #expect(CodeownerResolver.matches(pattern: "package.json", filePath: "package.json"))
        #expect(!CodeownerResolver.matches(pattern: "package.json", filePath: "sub/other.json"))
    }

    @Test func anchoredPatternMatchesFromRoot() {
        #expect(CodeownerResolver.matches(pattern: "/docs/", filePath: "docs/guide.md"))
        #expect(!CodeownerResolver.matches(pattern: "/docs/", filePath: "src/docs/guide.md"))
    }

    @Test func directoryPatternMatchesFilesUnder() {
        #expect(CodeownerResolver.matches(pattern: "src/", filePath: "src/main.swift"))
        #expect(CodeownerResolver.matches(pattern: "src/", filePath: "src/nested/deep.swift"))
        #expect(!CodeownerResolver.matches(pattern: "src/", filePath: "lib/other.swift"))
    }

    @Test func anchoredFilePatternMatchesOnlyAtRoot() {
        #expect(CodeownerResolver.matches(pattern: "/package.json", filePath: "package.json"))
        #expect(!CodeownerResolver.matches(pattern: "/package.json", filePath: "sub/package.json"))
    }

    // MARK: - resolve(filePath:codeowners:)

    @Test func emptyCodeownersReturnsEmpty() {
        let result = CodeownerResolver.resolve(filePath: "any/file.swift", codeowners: [])
        #expect(result.isEmpty)
    }

    @Test func noMatchReturnsEmpty() {
        let owner = Codeowner(handle: "@alice", pathPattern: "*.go")
        let result = CodeownerResolver.resolve(filePath: "main.swift", codeowners: [owner])
        #expect(result.isEmpty)
    }

    @Test func singleMatchReturnsHandle() {
        let owner = Codeowner(handle: "@alice", pathPattern: "*.swift")
        let result = CodeownerResolver.resolve(filePath: "main.swift", codeowners: [owner])
        #expect(result == ["@alice"])
    }

    @Test func lastRuleWins() {
        // Two patterns both match; the last one should win
        let first = Codeowner(handle: "@alice", pathPattern: "*")
        let second = Codeowner(handle: "@bob", pathPattern: "*.swift")
        let result = CodeownerResolver.resolve(filePath: "main.swift", codeowners: [first, second])
        #expect(result == ["@bob"])
        #expect(!result.contains("@alice"))
    }

    @Test func multipleHandlesOnSamePattern() {
        let alice = Codeowner(handle: "@alice", pathPattern: "*.swift")
        let bob = Codeowner(handle: "@bob", pathPattern: "*.swift")
        let result = CodeownerResolver.resolve(filePath: "app.swift", codeowners: [alice, bob])
        #expect(result.sorted() == ["@alice", "@bob"])
    }

    @Test func laterNonMatchingRuleDoesNotClearPreviousMatch() {
        let swift = Codeowner(handle: "@alice", pathPattern: "*.swift")
        let go = Codeowner(handle: "@bob", pathPattern: "*.go")
        let result = CodeownerResolver.resolve(filePath: "app.swift", codeowners: [swift, go])
        #expect(result == ["@alice"])
    }

    @Test func catchAllFollowedBySpecificPattern() {
        let everyone = Codeowner(handle: "@team", pathPattern: "*")
        let docs = Codeowner(handle: "@docs-team", pathPattern: "docs/")
        let result = CodeownerResolver.resolve(filePath: "docs/guide.md", codeowners: [everyone, docs])
        #expect(result == ["@docs-team"])
    }

    @Test func nilPatternCatchAllIsOverriddenBySpecificPattern() {
        let catchAll = Codeowner(handle: "@everyone", pathPattern: nil)
        let specific = Codeowner(handle: "@alice", pathPattern: "*.swift")
        let result = CodeownerResolver.resolve(filePath: "main.swift", codeowners: [catchAll, specific])
        #expect(result == ["@alice"])
    }
}
