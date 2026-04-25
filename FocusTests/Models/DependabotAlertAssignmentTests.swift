import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - DependabotAlertAssignmentTests

/// Tests for `DependabotAlert` assignment behavior.
@Suite("DependabotAlert Assignment Tests")
@MainActor // Required because DependabotAlert is a SwiftData @Model accessed via mainContext
struct DependabotAlertAssignmentTests {

    // MARK: - Setup

    /// Creates an in-memory `ModelContainer` with `SavedRepository` and `DependabotAlert` registered.
    private func makeContainer() throws -> ModelContainer { try makeTestContainer() }

    /// Creates a `DependabotAlert` with representative test values.
    private func makeAlert() -> DependabotAlert {
        DependabotAlert(
            alertNumber: 1,
            packageName: "lodash",
            severity: "high",
            fixVersion: "4.17.21",
            createdAt: Date()
        )
    }

    // MARK: - assignedLogins

    /// Verifies that a newly created alert has no assigned logins.
    @Test func defaultAssignedLoginsIsEmpty() {
        let alert = makeAlert()
        #expect(alert.assignedLogins.isEmpty)
    }

    /// Verifies that assigned logins can be set and read back.
    @Test func canSetAssignedLogins() {
        let alert = makeAlert()
        alert.assignedLogins = ["alice", "bob"]
        #expect(alert.assignedLogins == ["alice", "bob"])
    }

    /// Verifies that assigned logins can be cleared after being set.
    @Test func canClearAssignedLogins() {
        let alert = makeAlert()
        alert.assignedLogins = ["alice"]
        alert.assignedLogins = []
        #expect(alert.assignedLogins.isEmpty)
    }

    /// Verifies that assigned logins round-trip correctly through SwiftData persistence.
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

    /// Verifies that setting assigned logins does not modify other alert fields.
    @Test func assignedLoginsDoNotAffectOtherFields() {
        let alert = makeAlert()
        alert.assignedLogins = ["eve"]
        #expect(alert.packageName == "lodash")
        #expect(alert.severity == "high")
        #expect(alert.alertNumber == 1)
    }
}
