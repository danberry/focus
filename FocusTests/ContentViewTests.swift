import Testing
import SwiftData
@testable import Focus

/// Tests for `ContentView`.
@Suite("ContentView Tests")
@MainActor // Required because ContentView is isolated to the main actor in Swift 6
struct ContentViewTests {

    /// Verifies that `ContentView` can be instantiated with an in-memory model container.
    @Test func contentViewExists() throws {
        let container = try makeTestContainer()
        let view = ContentView()
            .modelContainer(container)
        #expect(view != nil)
    }
}
