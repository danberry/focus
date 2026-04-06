import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - DependabotAlertAssignmentTests

@Suite("DependabotAlert Assignment Tests")
@MainActor
struct DependabotAlertAssignmentTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SavedRepository.self, DependabotAlert.self,
            configurations: config
        )
    }

    private func makeAlert() -> DependabotAlert {
        DependabotAlert(
            alertNumber: 1,
            packageName: "lodash",
            severity: "high",
            fixVersion: "4.17.21",
            createdAt: Date()
        )
    }

    // MARK: - Tests

    @Test func defaultAssignedLoginsIsEmpty() {
        let alert = makeAlert()
        #expect(alert.assignedLogins.isEmpty)
    }

    @Test func canSetAssignedLogins() {
        let alert = makeAlert()
        alert.assignedLogins = ["alice", "bob"]
        #expect(alert.assignedLogins == ["alice", "bob"])
    }

    @Test func canClearAssignedLogins() {
        let alert = makeAlert()
        alert.assignedLogins = ["alice"]
        alert.assignedLogins = []
        #expect(alert.assignedLogins.isEmpty)
    }

    @Test func assignedLoginsPersistInSwiftData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let repo = SavedRepository(githubId: "R_1", owner: "acme", name: "api", displayName: "Acme API")
        context.insert(repo)

        let alert = makeAlert()
        alert.assignedLogins = ["carol", "dave"]
        alert.repository = repo
        context.insert(alert)
        try context.save()

        let descriptor = FetchDescriptor<DependabotAlert>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched[0].assignedLogins == ["carol", "dave"])
    }

    @Test func assignedLoginsDoNotAffectOtherFields() {
        let alert = makeAlert()
        alert.assignedLogins = ["eve"]
        #expect(alert.packageName == "lodash")
        #expect(alert.severity == "high")
        #expect(alert.alertNumber == 1)
    }
}
