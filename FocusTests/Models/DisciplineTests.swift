import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - DisciplineTests

@Suite("Discipline Tests")
@MainActor
struct DisciplineTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Discipline.self, JobTitle.self, configurations: config)
    }

    // MARK: - Tests

    @Test func initializesWithName() {
        let discipline = Discipline(name: "Engineering")
        #expect(discipline.name == "Engineering")
        #expect(discipline.jobTitles.isEmpty)
    }

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

    @Test func addingJobTitleIncreasesCount() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        discipline.jobTitles.append(JobTitle(name: "Engineer I"))
        discipline.jobTitles.append(JobTitle(name: "Senior Engineer"))
        try context.save()

        #expect(discipline.jobTitles.count == 2)
    }

    @Test func deletingDisciplineCascadesToJobTitles() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        discipline.jobTitles.append(JobTitle(name: "Engineer I"))
        discipline.jobTitles.append(JobTitle(name: "Senior Engineer"))
        try context.save()

        context.delete(discipline)
        try context.save()

        let jobTitleDescriptor = FetchDescriptor<JobTitle>()
        let remainingTitles = try context.fetch(jobTitleDescriptor)

        #expect(remainingTitles.isEmpty)
    }
}
