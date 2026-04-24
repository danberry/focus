import SwiftUI
import SwiftData

// MARK: - FocusApp

/// The app's entry point, responsible for composing the root scene and wiring dependencies.
///
/// `FocusApp` creates the `ModelContainer` once and shares it with `BackgroundSyncManager`,
/// injects `AuthenticationService` and `BackgroundSyncManager` into the environment,
/// and conditionally renders the main interface or lock screen based on authentication state.
@main
struct FocusApp: App {

    // MARK: - Properties

    /// The SwiftData model container, created once and shared with `BackgroundSyncManager`.
    private let modelContainer = try! ModelContainer(for: SavedRepository.self, Team.self, Member.self, MemberContribution.self, DailyContribution.self, Discipline.self, JobTitle.self, RepositoryVelocity.self, SavedOrganization.self, Department.self, SecurityWeeklySnapshot.self)

    /// The current scene phase, used to trigger a sync when the app becomes active.
    @Environment(\.scenePhase) private var scenePhase

    /// The authentication service managing the user's GitHub session state.
    @State private var authService = AuthenticationService()

    /// The background sync manager coordinating scheduled data synchronization.
    @State private var syncManager = BackgroundSyncManager()

    /// The briefing manager caching the weekly Focus Briefing.
    @State private var briefingManager = BriefingManager()

    // MARK: - Body

    /// The app's root scene.
    var body: some Scene {
        WindowGroup {
            Group {
                switch authService.authState {
                case .unauthenticated, .authenticated:
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        MainSplitView()
                    } else {
                        MainTabView()
                    }
                case .locked:
                    LockView()
                }
            }
            .task {
                // Register the BGProcessingTask handler before the app finishes launching.
                syncManager.setup(
                    modelContainer: modelContainer,
                    tokenProvider: authService.tokenProvider
                )
                syncManager.scheduleNextSync()
                // Sync on fresh launch — onChange(of: scenePhase) only fires on transitions,
                // so it misses the initial .active state when the app is cold-started.
                guard authService.authState == .authenticated else { return }
                let context = ModelContext(modelContainer)
                await syncManager.syncIfNeeded(context: context)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, authService.authState == .authenticated else { return }
                Task { @MainActor in
                    let context = ModelContext(modelContainer)
                    await syncManager.syncIfNeeded(context: context)
                }
            }
        }
        .environment(authService)
        .environment(syncManager)
        .environment(briefingManager)
        .modelContainer(modelContainer)
    }
}
