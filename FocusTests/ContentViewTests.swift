import Testing
import SwiftData
@testable import Focus

@Suite("ContentView Tests")
@MainActor
struct ContentViewTests {

    @Test func contentViewExists() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SavedRepository.self, configurations: config)
        let view = ContentView()
            .modelContainer(container)
        #expect(view != nil)
    }
}
