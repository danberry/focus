import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - MemberTests

/// Tests for `Member`.
@Suite("Member Tests")
@MainActor // Required because SwiftData's ModelContext is main-actor-bound
struct MemberTests {

    /// Creates an in-memory `ModelContainer` with the Member graph model types registered.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Member.self, Discipline.self, JobTitle.self,
            Department.self, SavedOrganization.self, SavedRepository.self,
            configurations: config
        )
    }

    // MARK: - init

    /// Verifies that a member initializes with only a name when no GitHub ID is provided.
    @Test func initializesWithNameOnly() {
        let member = Member(name: "Alice")
        #expect(member.name == "Alice")
        #expect(member.githubId == nil)
    }

    /// Verifies that a member initializes with both a name and a GitHub ID.
    @Test func initializesWithGitHubId() {
        let member = Member(name: "Alice", githubId: 1234567)
        #expect(member.name == "Alice")
        #expect(member.githubId == 1234567)
    }

    // MARK: - Persistence

    /// Verifies that a member can be inserted into a SwiftData context and fetched back.
    @Test func insertAndFetchFromContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        context.insert(Member(name: "Alice", githubId: 1234567))
        try context.save()

        let descriptor = FetchDescriptor<Member>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].name == "Alice")
        #expect(results[0].githubId == 1234567)
    }

    /// Verifies that multiple members are returned in ascending alphabetical order when sorted by name.
    @Test func multipleMembersAreFetchedSortedByName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        context.insert(Member(name: "Charlie"))
        context.insert(Member(name: "Alice"))
        context.insert(Member(name: "Bob"))
        try context.save()

        let descriptor = FetchDescriptor<Member>(sortBy: [SortDescriptor(\Member.name)])
        let results = try context.fetch(descriptor)

        #expect(results.map(\.name) == ["Alice", "Bob", "Charlie"])
    }

    // MARK: - team

    /// Verifies that assigning a team to a member creates the expected inverse relationship.
    @Test func memberBelongsToTeam() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let team = Team(name: "iOS Platform", teamDescription: "Owns the iOS app")
        context.insert(team)

        let member = Member(name: "Alice")
        member.team = team
        context.insert(member)
        try context.save()

        let descriptor = FetchDescriptor<Team>()
        let teams = try context.fetch(descriptor)
        #expect(teams[0].members.count == 1)
        #expect(teams[0].members[0].name == "Alice")
    }

    /// Verifies that deleting a team also deletes all of its members from the context.
    @Test func deletingTeamCascadesToMembers() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let team = Team(name: "iOS Platform", teamDescription: "Owns the iOS app")
        context.insert(team)

        let member = Member(name: "Alice")
        member.team = team
        context.insert(member)
        try context.save()

        context.delete(team)
        try context.save()

        let memberDescriptor = FetchDescriptor<Member>()
        let remainingMembers = try context.fetch(memberDescriptor)
        #expect(remainingMembers.isEmpty)
    }

    // MARK: - jobTitle

    /// Verifies that a member can be assigned a job title and that the discipline relationship resolves correctly.
    @Test func memberCanHaveJobTitle() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        let jobTitle = JobTitle(name: "Senior Engineer")
        discipline.jobTitles.append(jobTitle)

        let member = Member(name: "Alice")
        member.jobTitle = jobTitle
        context.insert(member)
        try context.save()

        let descriptor = FetchDescriptor<Member>()
        let results = try context.fetch(descriptor)

        #expect(results[0].jobTitle?.name == "Senior Engineer")
        #expect(results[0].jobTitle?.discipline?.name == "Engineering")
    }

    /// Verifies that deleting a member leaves the associated job title intact in the context.
    @Test func deletingMemberDoesNotDeleteJobTitle() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let discipline = Discipline(name: "Engineering")
        context.insert(discipline)
        let jobTitle = JobTitle(name: "Senior Engineer")
        discipline.jobTitles.append(jobTitle)

        let member = Member(name: "Alice")
        member.jobTitle = jobTitle
        context.insert(member)
        try context.save()

        context.delete(member)
        try context.save()

        let jobTitleDescriptor = FetchDescriptor<JobTitle>()
        let remainingTitles = try context.fetch(jobTitleDescriptor)
        #expect(remainingTitles.count == 1)
        #expect(remainingTitles[0].name == "Senior Engineer")
    }
}
