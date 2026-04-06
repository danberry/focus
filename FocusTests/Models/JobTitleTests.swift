import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - JobTitleTests

@Suite("Job Title Tests")
@MainActor
struct JobTitleTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Discipline.self, JobTitle.self, configurations: config)
    }

    // MARK: - Tests

    @Test func initializesWithName() {
        let jobTitle = JobTitle(name: "Senior Engineer")
        #expect(jobTitle.name == "Senior Engineer")
    }

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
