import Testing
import SwiftData
@testable import Focus

/// Tests for `ContentView`.
@Suite("ContentView Tests")
@MainActor // Required because ContentView is isolated to the main actor in Swift 6
struct ContentViewTests {

    /// Verifies that `ContentView` can be instantiated with an in-memory model container.
    @Test func contentViewExists() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SavedRepository.self, Team.self, Department.self, SavedOrganization.self,
            configurations: config
        )
        let view = ContentView()
            .modelContainer(container)
        #expect(view != nil)
    }
}
