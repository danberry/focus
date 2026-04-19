import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - DepartmentTests

/// Tests for `Department`.
@Suite("Department Tests")
@MainActor // Required because SwiftData model context operations run on the main actor.
struct DepartmentTests {

    /// Creates an in-memory `ModelContainer` with the department and its related types registered.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Department.self,
            Team.self,
            SavedOrganization.self,
            SavedRepository.self,
            Member.self,
            configurations: config
        )
    }

    // MARK: - init

    /// Verifies that a new `Department` initializes with the given name, a nil description, and an empty teams list.
    @Test func initializesWithName() {
        let department = Department(name: "Platform")
        #expect(department.name == "Platform")
        #expect(department.departmentDescription == nil)
        #expect(department.teams.isEmpty)
    }

    /// Verifies that a new `Department` initializes with both a name and a description.
    @Test func initializesWithDescription() {
        let department = Department(name: "Platform", departmentDescription: "Owns shared platform infrastructure")
        #expect(department.name == "Platform")
        #expect(department.departmentDescription == "Owns shared platform infrastructure")
    }

    // MARK: - Persistence

    /// Verifies that a department can be inserted and retrieved from a SwiftData context.
    @Test func insertAndFetchFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let department = Department(name: "Platform")
        context.insert(department)
        try context.save()

        let descriptor = FetchDescriptor<Department>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].name == "Platform")
    }

    /// Verifies that a deleted department is no longer present in the SwiftData context.
    @Test func deleteFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let department = Department(name: "Platform")
        context.insert(department)
        try context.save()

        context.delete(department)
        try context.save()

        let descriptor = FetchDescriptor<Department>()
        let results = try context.fetch(descriptor)

        #expect(results.isEmpty)
    }

    /// Verifies that multiple departments are returned in ascending alphabetical order when sorted by name.
    @Test func multipleDepartmentsAreFetchedSortedByName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        context.insert(Department(name: "Product"))
        context.insert(Department(name: "Engineering"))
        context.insert(Department(name: "Design"))
        try context.save()

        let descriptor = FetchDescriptor<Department>(sortBy: [SortDescriptor(\Department.name)])
        let results = try context.fetch(descriptor)

        #expect(results.map(\.name) == ["Design", "Engineering", "Product"])
    }

    // MARK: - Relationships

    /// Verifies that appending teams to a department increases the count correctly.
    @Test func addingTeamIncreasesCount() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let department = Department(name: "Platform")
        context.insert(department)
        department.teams.append(Team(name: "iOS Platform", teamDescription: "Owns the iOS app"))
        department.teams.append(Team(name: "Web Platform", teamDescription: "Owns the web app"))
        try context.save()

        #expect(department.teams.count == 2)
    }

    /// Verifies that deleting a department nullifies its teams rather than cascade-deleting them.
    @Test func deletingDepartmentNullifiesTeams() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let department = Department(name: "Platform")
        context.insert(department)
        department.teams.append(Team(name: "iOS Platform", teamDescription: "Owns the iOS app"))
        department.teams.append(Team(name: "Web Platform", teamDescription: "Owns the web app"))
        try context.save()

        context.delete(department)
        try context.save()

        let teamDescriptor = FetchDescriptor<Team>()
        let remainingTeams = try context.fetch(teamDescriptor)

        #expect(remainingTeams.count == 2)
        #expect(remainingTeams.allSatisfy { $0.department == nil })
    }

    /// Verifies that assigning a department to an organization links both sides of the relationship.
    @Test func assigningOrganizationLinksBothSides() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let organization = SavedOrganization(githubId: "org-1", login: "acme")
        let department = Department(name: "Platform")
        context.insert(organization)
        context.insert(department)
        organization.departments.append(department)
        try context.save()

        #expect(organization.departments.count == 1)
        #expect(department.organization === organization)
    }
}
