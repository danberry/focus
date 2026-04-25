import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - JobTitleTests

/// Tests for `JobTitle`.
@Suite("Job Title Tests")
@MainActor // Required because SwiftData ModelContext operations are @MainActor
struct JobTitleTests {

    /// Creates an in-memory `ModelContainer` with `Discipline` and `JobTitle` registered.
    private func makeContainer() throws -> ModelContainer { try makeTestContainer() }

    // MARK: - Initialization

    /// Verifies that a `JobTitle` initializes with the given name.
    @Test func initializesWithName() {
        let jobTitle = JobTitle(name: "Senior Engineer")
        #expect(jobTitle.name == "Senior Engineer")
    }

    // MARK: - Persistence

    /// Verifies that a `JobTitle` can be inserted into and fetched from a SwiftData context.
    @Test func insertAndFetchFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        let jobTitle = JobTitle(name: "Senior Engineer")
        discipline.jobTitles.append(jobTitle)
        try context.save()

        let descriptor = FetchDescriptor<JobTitle>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].name == "Senior Engineer")
    }

    /// Verifies that a deleted `JobTitle` is no longer returned by a fetch descriptor.
    @Test func deleteFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        let jobTitle = JobTitle(name: "Senior Engineer")
        discipline.jobTitles.append(jobTitle)
        try context.save()

        context.delete(jobTitle)
        try context.save()

        let descriptor = FetchDescriptor<JobTitle>()
        let results = try context.fetch(descriptor)

        #expect(results.isEmpty)
    }

    /// Verifies that updating the `name` property persists the change to SwiftData.
    @Test func inlineEditUpdatesPersistedName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        let jobTitle = JobTitle(name: "Engineer I")
        discipline.jobTitles.append(jobTitle)
        try context.save()

        jobTitle.name = "Senior Engineer"
        try context.save()

        let descriptor = FetchDescriptor<JobTitle>()
        let results = try context.fetch(descriptor)

        #expect(results[0].name == "Senior Engineer")
    }

    // MARK: - Relationships

    /// Verifies that a `JobTitle` carries a back-reference to its parent `Discipline` after insertion.
    @Test func jobTitleBelongsToDiscipline() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        let jobTitle = JobTitle(name: "Senior Engineer")
        discipline.jobTitles.append(jobTitle)
        try context.save()

        #expect(jobTitle.discipline?.name == "Engineering")
    }
}
