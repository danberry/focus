import Testing
@testable import Focus

@Suite("ContentView Tests")
struct ContentViewTests {

    @Test func contentViewExists() {
        let view = ContentView()
        #expect(view != nil)
    }
}
