import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - SavedRepositoryTests

@Suite("SavedRepository Tests")
@MainActor
struct SavedRepositoryTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SavedRepository.self, configurations: config)
    }

    // MARK: - Tests

    @Test func initializesWithAllFields() {
        let repo = SavedRepository(githubId: "MDEwOlJlcG9zaXRvcnk0NDgzODAxMg==", owner: "apple", name: "swift", displayName: "Apple Swift", primaryLanguage: "Swift")
        #expect(repo.githubId == "MDEwOlJlcG9zaXRvcnk0NDgzODAxMg==")
        #expect(repo.owner == "apple")
        #expect(repo.name == "swift")
        #expect(repo.displayName == "Apple Swift")
        #expect(repo.primaryLanguage == "Swift")
    }

    @Test func initializesWithNilLanguage() {
        let repo = SavedRepository(githubId: "abc123", owner: "apple", name: "swift", displayName: "Apple Swift")
        #expect(repo.primaryLanguage == nil)
    }

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

    @Test func totalSecurityAlertsIsZeroWhenAllZero() {
        let repo = SavedRepository(githubId: "abc123", owner: "apple", name: "swift", displayName: "Apple Swift")
        #expect(repo.totalSecurityAlerts == 0)
    }

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
}
