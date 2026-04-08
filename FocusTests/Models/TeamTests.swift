import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - TeamTests

@Suite("Team Tests")
@MainActor
struct TeamTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Team.self, configurations: config)
    }

    // MARK: - Tests

    @Test func initializesWithAllFields() {
        let team = Team(name: "iOS Platform", teamDescription: "Owns the iOS app")
        #expect(team.name == "iOS Platform")
        #expect(team.teamDescription == "Owns the iOS app")
    }

    @Test func insertAndFetchFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let team = Team(name: "iOS Platform", teamDescription: "Owns the iOS app")
        context.insert(team)
        try context.save()

        let descriptor = FetchDescriptor<Team>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].name == "iOS Platform")
        #expect(results[0].teamDescription == "Owns the iOS app")
    }

    @Test func deleteFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let team = Team(name: "iOS Platform", teamDescription: "Owns the iOS app")
        context.insert(team)
        try context.save()

        context.delete(team)
        try context.save()

        let descriptor = FetchDescriptor<Team>()
        let results = try context.fetch(descriptor)

        #expect(results.isEmpty)
    }

    @Test func multipleTeamsAreFetchedSortedByName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        context.insert(Team(name: "Web Platform", teamDescription: "Owns the web app"))
        context.insert(Team(name: "Android Platform", teamDescription: "Owns the Android app"))
        context.insert(Team(name: "iOS Platform", teamDescription: "Owns the iOS app"))
        try context.save()

        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\Team.name, comparator: .localizedStandard)])
        let results = try context.fetch(descriptor)

        #expect(results.map(\.name) == ["Android Platform", "iOS Platform", "Web Platform"])
    }
}
