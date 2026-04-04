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
        let repo = SavedRepository(githubId: "MDEwOlJlcG9zaXRvcnk0NDgzODAxMg==", name: "swift", primaryLanguage: "Swift")
        #expect(repo.githubId == "MDEwOlJlcG9zaXRvcnk0NDgzODAxMg==")
        #expect(repo.name == "swift")
        #expect(repo.primaryLanguage == "Swift")
    }

    @Test func initializesWithNilLanguage() {
        let repo = SavedRepository(githubId: "abc123", name: "swift")
        #expect(repo.primaryLanguage == nil)
    }

    @Test func insertAndFetchFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let repo = SavedRepository(githubId: "abc123", name: "swift", primaryLanguage: "Swift")
        context.insert(repo)
        try context.save()

        let descriptor = FetchDescriptor<SavedRepository>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].githubId == "abc123")
        #expect(results[0].name == "swift")
        #expect(results[0].primaryLanguage == "Swift")
    }

    @Test func deleteFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let repo = SavedRepository(githubId: "abc123", name: "swift")
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

        context.insert(SavedRepository(githubId: "id1", name: "zed"))
        context.insert(SavedRepository(githubId: "id2", name: "apple"))
        context.insert(SavedRepository(githubId: "id3", name: "vapor"))
        try context.save()

        let descriptor = FetchDescriptor<SavedRepository>(
            sortBy: [SortDescriptor(\SavedRepository.name)]
        )
        let results = try context.fetch(descriptor)

        #expect(results.map(\.name) == ["apple", "vapor", "zed"])
    }
}
