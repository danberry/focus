import SwiftUI
import SwiftData

@main
struct FocusApp: App {
    @State private var authService = AuthenticationService()

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView()
            } else {
                LoginView()
            }
        }
        .environment(authService)
        .modelContainer(for: SavedRepository.self)
    }
}
