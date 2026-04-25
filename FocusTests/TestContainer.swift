import SwiftData
@testable import Focus

// MARK: - Test container

/// Creates an in-memory `ModelContainer` with every `@Model` type registered.
///
/// All test suites that use SwiftData must share the same schema so that
/// CoreData's in-process schema cache doesn't see conflicting model descriptions.
/// New `@Model` types should be added here when they are added to the app.
func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for:
            SavedRepository.self,
            Team.self,
            Member.self,
            MemberContribution.self,
            DailyContribution.self,
            Discipline.self,
            JobTitle.self,
            RepositoryVelocity.self,
            SavedOrganization.self,
            Department.self,
            SecurityWeeklySnapshot.self,
        configurations: config
    )
}
