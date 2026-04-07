import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - MemberTests

@Suite("Member Tests")
@MainActor
struct MemberTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Team.self, Member.self, Discipline.self, JobTitle.self, configurations: config)
    }

    // MARK: - Tests

    @Test func initializesWithNameOnly() {
        let member = Member(name: "Alice")
        #expect(member.name == "Alice")
        #expect(member.githubId == nil)
    }

    @Test func initializesWithGitHubId() {
        let member = Member(name: "Alice", githubId: 1234567)
        #expect(member.name == "Alice")
        #expect(member.githubId == 1234567)
    }

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
}
