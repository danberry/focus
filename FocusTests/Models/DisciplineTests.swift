import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - DisciplineTests

/// Tests for `Discipline`.
@Suite("Discipline Tests")
@MainActor // Required because SwiftData model context operations run on the main actor.
struct DisciplineTests {

    /// Creates an in-memory `ModelContainer` with `Discipline` and `JobTitle` registered.
    private func makeContainer() throws -> ModelContainer { try makeTestContainer() }

    // MARK: - init

    /// Verifies that a new `Discipline` initializes with the given name and an empty job titles list.
    @Test func initializesWithName() {
        let discipline = Discipline(name: "Engineering")
        #expect(discipline.name == "Engineering")
        #expect((discipline.jobTitles ?? []).isEmpty)
    }

    // MARK: - Persistence

    /// Verifies that a discipline can be inserted and retrieved from a SwiftData context.
    @Test func insertAndFetchFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        try context.save()

        let descriptor = FetchDescriptor<Discipline>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].name == "Engineering")
    }

    /// Verifies that a deleted discipline is no longer present in the SwiftData context.
    @Test func deleteFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        try context.save()

        context.delete(discipline)
        try context.save()

        let descriptor = FetchDescriptor<Discipline>()
        let results = try context.fetch(descriptor)

        #expect(results.isEmpty)
    }

    /// Verifies that multiple disciplines are returned in ascending alphabetical order when sorted by name.
    @Test func multipleDisciplinesAreFetchedSortedByName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        context.insert(Discipline(name: "Product"))
        context.insert(Discipline(name: "Engineering"))
        context.insert(Discipline(name: "Design"))
        try context.save()

        let descriptor = FetchDescriptor<Discipline>(sortBy: [SortDescriptor(\Discipline.name)])
        let results = try context.fetch(descriptor)

        #expect(results.map(\.name) == ["Design", "Engineering", "Product"])
    }

    // MARK: - Relationships

    /// Verifies that appending job titles to a discipline increases the count correctly.
    @Test func addingJobTitleIncreasesCount() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        discipline.jobTitles = (discipline.jobTitles ?? []) + [
            JobTitle(name: "Engineer I"),
            JobTitle(name: "Senior Engineer")
        ]
        try context.save()

        #expect(discipline.jobTitles?.count == 2)
    }

    /// Verifies that deleting a discipline cascade-deletes its associated job titles.
    @Test func deletingDisciplineCascadesToJobTitles() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        discipline.jobTitles = (discipline.jobTitles ?? []) + [
            JobTitle(name: "Engineer I"),
            JobTitle(name: "Senior Engineer")
        ]
        try context.save()

        context.delete(discipline)
        try context.save()

        let jobTitleDescriptor = FetchDescriptor<JobTitle>()
        let remainingTitles = try context.fetch(jobTitleDescriptor)

        #expect(remainingTitles.isEmpty)
    }
}
