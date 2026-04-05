import SwiftUI
import SwiftData

@main
struct FocusApp: App {
    @State private var authService = AuthenticationService()
    @State private var syncManager = BackgroundSyncManager()
    @Environment(\.scenePhase) private var scenePhase

    // Create the container once so it can be shared with BackgroundSyncManager.
    private let modelContainer = try! ModelContainer(for: SavedRepository.self, Team.self, Member.self, MemberContribution.self)

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .task {
                // Register the BGProcessingTask handler before the app finishes launching.
                syncManager.setup(
                    modelContainer: modelContainer,
                    tokenProvider: authService.tokenProvider
                )
                syncManager.scheduleNextSync()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, authService.isAuthenticated else { return }
                Task { @MainActor in
                    let context = ModelContext(modelContainer)
                    await syncManager.syncIfNeeded(context: context)
                }
            }
        }
        .environment(authService)
        .environment(syncManager)
        .modelContainer(modelContainer)
    }
}
