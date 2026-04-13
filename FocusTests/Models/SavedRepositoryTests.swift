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
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SavedRepository.self, DependabotAlert.self, CodeScanningAlert.self, SecretScanningAlert.self,
            configurations: config
        )
    }

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

    /// Verifies that `totalSecurityAlerts` returns the sum of all three alert type counts.
    @Test func totalSecurityAlertsReturnsSumOfAllCounts() {
        let repo = SavedRepository(
            githubId: "abc123",
            owner: "apple",
            name: "swift",
            displayName: "Apple Swift",
            dependabotAlerts: 3,
            codeScanningAlerts: 5,
            secretScanningAlerts: 1
        )
        #expect(repo.totalSecurityAlerts == 9)
    }

    /// Verifies that `totalSecurityAlerts` returns `0` when all alert counts are at their default value.
    @Test func totalSecurityAlertsIsZeroWhenAllZero() {
        let repo = SavedRepository(githubId: "abc123", owner: "apple", name: "swift", displayName: "Apple Swift")
        #expect(repo.totalSecurityAlerts == 0)
    }
}
