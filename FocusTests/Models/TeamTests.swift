import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - TeamTests

/// Tests for `Team`.
@Suite("Team Tests")
@MainActor // Required because ModelContext operations run on the main actor
struct TeamTests {

    /// Creates an in-memory `ModelContainer` configured for `Team` objects.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Department.self, SavedOrganization.self, SavedRepository.self, Member.self,
            configurations: config
        )
    }

    // MARK: - init

    /// Verifies that all properties are set correctly when a team is created.
    @Test func initializesWithAllFields() {
        let team = Team(name: "iOS Platform", teamDescription: "Owns the iOS app")
        #expect(team.name == "iOS Platform")
        #expect(team.teamDescription == "Owns the iOS app")
    }

    // MARK: - Persistence

    /// Verifies that a team inserted into a SwiftData context can be fetched back.
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

    /// Verifies that deleting a team removes it from the SwiftData context.
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

    /// Verifies that multiple teams are returned in alphabetical order when fetched with a name sort descriptor.
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
