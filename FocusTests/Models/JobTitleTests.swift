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
        return try ModelContainer(for: JobTitle.self, configurations: config)
    }

    // MARK: - Tests

    @Test func initializesWithAllFields() {
        let jobTitle = JobTitle(name: "iOS Engineer", level: "Senior")
        #expect(jobTitle.name == "iOS Engineer")
        #expect(jobTitle.level == "Senior")
    }

    @Test func insertAndFetchFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let jobTitle = JobTitle(name: "iOS Engineer", level: "Senior")
        context.insert(jobTitle)
        try context.save()

        let descriptor = FetchDescriptor<JobTitle>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].name == "iOS Engineer")
        #expect(results[0].level == "Senior")
    }

    @Test func deleteFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let jobTitle = JobTitle(name: "iOS Engineer", level: "Senior")
        context.insert(jobTitle)
        try context.save()

        context.delete(jobTitle)
        try context.save()

        let descriptor = FetchDescriptor<JobTitle>()
        let results = try context.fetch(descriptor)

        #expect(results.isEmpty)
    }

    @Test func multipleJobTitlesAreFetchedSortedByName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        context.insert(JobTitle(name: "Product Manager", level: "Senior"))
        context.insert(JobTitle(name: "Android Engineer", level: "Staff"))
        context.insert(JobTitle(name: "iOS Engineer", level: "Senior"))
        try context.save()

        let descriptor = FetchDescriptor<JobTitle>(sortBy: [SortDescriptor(\JobTitle.name)])
        let results = try context.fetch(descriptor)

        #expect(results.map(\.name) == ["Android Engineer", "iOS Engineer", "Product Manager"])
    }

    @Test func inlineEditUpdatesPersistedFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let jobTitle = JobTitle(name: "iOS Engineer", level: "Senior")
        context.insert(jobTitle)
        try context.save()

        jobTitle.name = "iOS Platform Engineer"
        jobTitle.level = "Staff"
        try context.save()

        let descriptor = FetchDescriptor<JobTitle>()
        let results = try context.fetch(descriptor)

        #expect(results[0].name == "iOS Platform Engineer")
        #expect(results[0].level == "Staff")
    }
}
