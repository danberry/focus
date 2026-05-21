import SwiftUI
import SwiftData
import OSLog
import CloudKit

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
    private let modelContainer: ModelContainer = makeFocusModelContainer()

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
                // Diagnose CloudKit account status on launch.
                let status = try? await CKContainer.default().accountStatus()
                switch status {
                case .available:       print("[Focus] ☁️ iCloud account: available")
                case .noAccount:       print("[Focus] ☁️ iCloud account: NO ACCOUNT signed in")
                case .restricted:      print("[Focus] ☁️ iCloud account: restricted")
                case .couldNotDetermine: print("[Focus] ☁️ iCloud account: could not determine")
                case .temporarilyUnavailable: print("[Focus] ☁️ iCloud account: temporarily unavailable")
                default:               print("[Focus] ☁️ iCloud account: unknown status \(String(describing: status))")
                }

                // Register the BGProcessingTask handler before the app finishes launching.
                syncManager.setup(
                    modelContainer: modelContainer,
                    tokenProvider: authService.tokenProvider
                )
                syncManager.scheduleNextSync()

                // Remove any duplicate SavedRepository records before syncing.
                let context = ModelContext(modelContainer)
                deduplicateSavedRepositories(in: context)

                // Sync on fresh launch — onChange(of: scenePhase) only fires on transitions,
                // so it misses the initial .active state when the app is cold-started.
                guard authService.authState == .authenticated else { return }
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

// MARK: - Deduplication

/// Removes duplicate ``SavedRepository`` records that share the same `owner`/`name` pair.
///
/// For each group of duplicates the record with the most total related objects
/// (alerts, PRs, codeowners, velocity metrics, commit activity) is kept; the rest
/// are cascade-deleted from the context and flushed to the persistent store.
@MainActor
private func deduplicateSavedRepositories(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<SavedRepository>()) else { return }

    var groups: [String: [SavedRepository]] = [:]
    for repo in all {
        groups["\(repo.owner)/\(repo.name)", default: []].append(repo)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted { lhs, rhs in
            repositoryRichness(lhs) > repositoryRichness(rhs)
        }
        for duplicate in ranked.dropFirst() {
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate repository record(s)")
    }
}

/// Returns a richness score for a repository based on the count of its related records.
private func repositoryRichness(_ repo: SavedRepository) -> Int {
    (repo.dependabotAlertDetails?.count ?? 0) +
    (repo.codeScanningAlertDetails?.count ?? 0) +
    (repo.secretScanningAlertDetails?.count ?? 0) +
    (repo.codeowners?.count ?? 0) +
    (repo.openPullRequests?.count ?? 0) +
    (repo.velocityMetrics?.count ?? 0) +
    (repo.commitActivity?.count ?? 0)
}

// MARK: - ModelContainer

private let containerLogger = Logger(subsystem: "com.danberry.Focus", category: "ModelContainer")

/// Builds the app's SwiftData model container, preferring a CloudKit-backed store.
///
/// Attempts to open the existing store at the default SwiftData URL with
/// `cloudKitDatabase: .automatic` so iCloud sync is enabled and existing local
/// data migrates transparently. Falls back to a local-only store at the same
/// URL if CloudKit initialisation fails (e.g. no iCloud account signed in,
/// entitlement mismatch in a development build, or simulator without iCloud).
private func makeFocusModelContainer() -> ModelContainer {
    let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")

    let allTypes: [any PersistentModel.Type] = [
        SavedRepository.self,
        DependabotAlert.self,
        CodeScanningAlert.self,
        SecretScanningAlert.self,
        Codeowner.self,
        OpenPullRequest.self,
        RepositoryVelocity.self,
        Team.self,
        Member.self,
        MemberContribution.self,
        DailyContribution.self,
        Discipline.self,
        JobTitle.self,
        SavedOrganization.self,
        Department.self,
        SecurityWeeklySnapshot.self,
        PRWeeklySnapshot.self,
        RepositoryCommitDay.self,
    ]

    // Prefer CloudKit-backed store so data roams across the user's devices.
    let cloudConfig = ModelConfiguration(url: storeURL, cloudKitDatabase: .automatic)
    do {
        let container = try ModelContainer(for: Schema(allTypes), configurations: cloudConfig)
        containerLogger.info("CloudKit-backed store opened at \(storeURL.path)")
        print("[Focus] ✅ CloudKit store opened successfully")
        return container
    } catch {
        containerLogger.error("CloudKit store failed (\(error)). Falling back to local-only store.")
        print("[Focus] ❌ CloudKit store FAILED — using local-only. Error: \(error)")
    }

    // Fallback: local-only store at the same URL — preserves existing data even
    // when CloudKit is unavailable (no iCloud account, simulator, CI, etc.).
    let localConfig = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
    // swiftlint:disable:next force_try
    return try! ModelContainer(for: Schema(allTypes), configurations: localConfig)
}
