import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - SavedRepositoryTests

/// Tests for `SavedRepository`.
@Suite("SavedRepository Tests")
@MainActor // Required because ModelContext operations must run on the main actor.
struct SavedRepositoryTests {

    /// Creates an in-memory `ModelContainer` with `SavedRepository` and all cascade-delete alert types registered.
    private func makeContainer() throws -> ModelContainer { try makeTestContainer() }

    // MARK: - init

    /// Verifies that all provided fields are stored correctly on initialization.
    @Test func initializesWithAllFields() {
        let repo = SavedRepository(githubId: "MDEwOlJlcG9zaXRvcnk0NDgzODAxMg==", owner: "apple", name: "swift", displayName: "Apple Swift", primaryLanguage: "Swift")
        #expect(repo.githubId == "MDEwOlJlcG9zaXRvcnk0NDgzODAxMg==")
        #expect(repo.owner == "apple")
        #expect(repo.name == "swift")
        #expect(repo.displayName == "Apple Swift")
        #expect(repo.primaryLanguage == "Swift")
    }

    /// Verifies that `primaryLanguage` defaults to `nil` when not provided.
    @Test func initializesWithNilLanguage() {
        let repo = SavedRepository(githubId: "abc123", owner: "apple", name: "swift", displayName: "Apple Swift")
        #expect(repo.primaryLanguage == nil)
    }

    // MARK: - Persistence

    /// Verifies that a repository can be inserted, saved, and fetched from a SwiftData context.
    @Test func insertAndFetchFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let repo = SavedRepository(githubId: "abc123", owner: "apple", name: "swift", displayName: "Apple Swift", primaryLanguage: "Swift")
        context.insert(repo)
        try context.save()

        let descriptor = FetchDescriptor<SavedRepository>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].githubId == "abc123")
        #expect(results[0].owner == "apple")
        #expect(results[0].name == "swift")
        #expect(results[0].displayName == "Apple Swift")
        #expect(results[0].primaryLanguage == "Swift")
    }

    /// Verifies that a deleted repository is no longer returned by a fetch.
    @Test func deleteFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let repo = SavedRepository(githubId: "abc123", owner: "apple", name: "swift", displayName: "Apple Swift")
        context.insert(repo)
        try context.save()

        context.delete(repo)
        try context.save()

        let descriptor = FetchDescriptor<SavedRepository>()
        let results = try context.fetch(descriptor)

        #expect(results.isEmpty)
    }

    /// Verifies that multiple repositories are returned in name-sorted order when a sort descriptor is applied.
    @Test func multipleRepositoriesAreFetchedSortedByName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        context.insert(SavedRepository(githubId: "id1", owner: "a", name: "zed", displayName: "Zed"))
        context.insert(SavedRepository(githubId: "id2", owner: "b", name: "apple", displayName: "Apple"))
        context.insert(SavedRepository(githubId: "id3", owner: "c", name: "vapor", displayName: "Vapor"))
        try context.save()

        let descriptor = FetchDescriptor<SavedRepository>(
            sortBy: [SortDescriptor(\SavedRepository.name)]
        )
        let results = try context.fetch(descriptor)

        #expect(results.map(\.name) == ["apple", "vapor", "zed"])
    }

    /// Verifies that `displayName` round-trips through persistence without modification.
    @Test func displayNameIsStoredAndRetrieved() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let repo = SavedRepository(githubId: "abc123", owner: "apple", name: "swift", displayName: "My Swift Repo")
        context.insert(repo)
        try context.save()

        let descriptor = FetchDescriptor<SavedRepository>()
        let results = try context.fetch(descriptor)

        #expect(results[0].displayName == "My Swift Repo")
    }

    // MARK: - totalSecurityAlerts

    /// Verifies that `totalSecurityAlerts` returns the sum of open alerts across all three types.
    @Test func totalSecurityAlertsReturnsSumOfAllCounts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let repo = SavedRepository(githubId: "abc123", owner: "apple", name: "swift", displayName: "Apple Swift")
        context.insert(repo)

        // 2 open Dependabot alerts (1 dismissed should not count)
        for i in 1...2 {
            let a = DependabotAlert(alertNumber: i, packageName: "pkg", severity: "low", fixVersion: nil, createdAt: Date(), state: "open")
            a.repository = repo; context.insert(a)
        }
        let dismissed = DependabotAlert(alertNumber: 3, packageName: "pkg", severity: "low", fixVersion: nil, createdAt: Date(), state: "dismissed")
        dismissed.repository = repo; context.insert(dismissed)

        // 3 open code scanning alerts (1 fixed should not count)
        for i in 1...3 {
            let a = CodeScanningAlert(alertNumber: i, ruleName: "rule", securitySeverityLevel: nil, createdAt: Date(), htmlUrl: "", state: "open")
            a.repository = repo; context.insert(a)
        }
        let fixed = CodeScanningAlert(alertNumber: 4, ruleName: "rule", securitySeverityLevel: nil, createdAt: Date(), htmlUrl: "", state: "fixed")
        fixed.repository = repo; context.insert(fixed)

        // 1 open secret scanning alert (1 resolved should not count)
        let open = SecretScanningAlert(alertNumber: 1, secretTypeDisplayName: "PAT", validity: "active", publiclyLeaked: false, createdAt: Date(), state: "open")
        open.repository = repo; context.insert(open)
        let resolved = SecretScanningAlert(alertNumber: 2, secretTypeDisplayName: "PAT", validity: "revoked", publiclyLeaked: false, createdAt: Date(), state: "resolved")
        resolved.repository = repo; context.insert(resolved)

        #expect(repo.dependabotAlerts == 2)
        #expect(repo.codeScanningAlerts == 3)
        #expect(repo.secretScanningAlerts == 1)
        #expect(repo.totalSecurityAlerts == 6)
    }

    /// Verifies that `totalSecurityAlerts` returns `0` when all alert counts are at their default value.
    @Test func totalSecurityAlertsIsZeroWhenAllZero() {
        let repo = SavedRepository(githubId: "abc123", owner: "apple", name: "swift", displayName: "Apple Swift")
        #expect(repo.totalSecurityAlerts == 0)
    }
}
