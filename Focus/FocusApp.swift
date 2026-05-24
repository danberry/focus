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
                // Register the BGProcessingTask handler before the app finishes launching.
                syncManager.setup(
                    modelContainer: modelContainer,
                    tokenProvider: authService.tokenProvider
                )
                syncManager.scheduleNextSync()

                // Remove any duplicate records created by CloudKit sync before syncing.
                let context = ModelContext(modelContainer)
                deduplicateSavedOrganizations(in: context)
                deduplicateSavedRepositories(in: context)
                deduplicateDisciplines(in: context)
                deduplicateJobTitles(in: context)
                deduplicateDepartments(in: context)
                deduplicateTeams(in: context)
                deduplicateMembers(in: context)
                deduplicateDependabotAlerts(in: context)
                deduplicateCodeScanningAlerts(in: context)
                deduplicateSecretScanningAlerts(in: context)
                deduplicateOpenPullRequests(in: context)

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
    let security = (repo.dependabotAlertDetails?.count ?? 0)
                 + (repo.codeScanningAlertDetails?.count ?? 0)
                 + (repo.secretScanningAlertDetails?.count ?? 0)
    let activity = (repo.codeowners?.count ?? 0)
                 + (repo.openPullRequests?.count ?? 0)
                 + (repo.velocityMetrics?.count ?? 0)
                 + (repo.commitActivity?.count ?? 0)
                 + (repo.releases?.count ?? 0)
    return security + activity
}

/// Removes duplicate ``Team`` records that share the same name.
///
/// For each group of duplicates the record with the most members and repositories is kept.
/// Members and repositories from duplicates are re-assigned to the canonical record before
/// deletion so no cascade-delete removes live data.
@MainActor
private func deduplicateTeams(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<Team>()) else { return }

    var groups: [String: [Team]] = [:]
    for team in all {
        groups[team.name, default: []].append(team)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted { teamRichness($0) > teamRichness($1) }
        let canonical = ranked[0]
        for duplicate in ranked.dropFirst() {
            if canonical.department == nil { canonical.department = duplicate.department }
            if canonical.organization == nil { canonical.organization = duplicate.organization }
            // Snapshot before iterating — relationship arrays mutate as we re-assign.
            let membersToMove = duplicate.members ?? []
            for member in membersToMove { member.team = canonical }
            let reposToMove = duplicate.repositories ?? []
            for repo in reposToMove { repo.team = canonical }
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate team record(s)")
    }
}

/// Returns a richness score for a team based on the count of its related records.
private func teamRichness(_ team: Team) -> Int {
    (team.members?.count ?? 0) + (team.repositories?.count ?? 0)
}

/// Removes duplicate ``Member`` records that share the same team and identity key.
///
/// Identity is the member's GitHub login when available, falling back to their display name.
/// For each group of duplicates the record with the most contribution data is kept.
@MainActor
private func deduplicateMembers(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<Member>()) else { return }

    var groups: [String: [Member]] = [:]
    for member in all {
        let teamKey = member.team?.name ?? ""
        let memberKey = member.githubLogin ?? member.name
        groups["\(teamKey):\(memberKey)", default: []].append(member)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted { memberRichness($0) > memberRichness($1) }
        for duplicate in ranked.dropFirst() {
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate member record(s)")
    }
}

/// Returns a richness score for a member based on the count of their contribution records.
private func memberRichness(_ member: Member) -> Int {
    (member.contributions?.count ?? 0) + (member.dailyContributions?.count ?? 0)
}

/// Removes duplicate ``SavedOrganization`` records that share the same GitHub ID.
///
/// Departments and teams from duplicates are re-assigned to the canonical record before
/// deletion to prevent cascade data loss.
@MainActor
private func deduplicateSavedOrganizations(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<SavedOrganization>()) else { return }

    var groups: [String: [SavedOrganization]] = [:]
    for org in all {
        groups[org.githubId, default: []].append(org)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted {
            ($0.departments?.count ?? 0) + ($0.teams?.count ?? 0) >
            ($1.departments?.count ?? 0) + ($1.teams?.count ?? 0)
        }
        let canonical = ranked[0]
        for duplicate in ranked.dropFirst() {
            for dept in duplicate.departments ?? [] { dept.organization = canonical }
            for team in duplicate.teams ?? [] { team.organization = canonical }
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate organization record(s)")
    }
}

/// Removes duplicate ``Discipline`` records that share the same name.
///
/// Job titles from duplicates are re-assigned to the canonical record before deletion
/// to prevent cascade data loss.
@MainActor
private func deduplicateDisciplines(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<Discipline>()) else { return }

    var groups: [String: [Discipline]] = [:]
    for discipline in all {
        groups[discipline.name, default: []].append(discipline)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted { ($0.jobTitles?.count ?? 0) > ($1.jobTitles?.count ?? 0) }
        let canonical = ranked[0]
        for duplicate in ranked.dropFirst() {
            for title in duplicate.jobTitles ?? [] { title.discipline = canonical }
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate discipline record(s)")
    }
}

/// Removes duplicate ``JobTitle`` records that share the same name.
///
/// Members from duplicates are re-assigned to the canonical record before deletion.
@MainActor
private func deduplicateJobTitles(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<JobTitle>()) else { return }

    var groups: [String: [JobTitle]] = [:]
    for title in all {
        groups[title.name, default: []].append(title)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted { ($0.members?.count ?? 0) > ($1.members?.count ?? 0) }
        let canonical = ranked[0]
        for duplicate in ranked.dropFirst() {
            for member in duplicate.members ?? [] { member.jobTitle = canonical }
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate job title record(s)")
    }
}

/// Removes duplicate ``Department`` records that share the same name.
///
/// Teams from duplicates are re-assigned to the canonical record before deletion.
@MainActor
private func deduplicateDepartments(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<Department>()) else { return }

    var groups: [String: [Department]] = [:]
    for dept in all {
        groups[dept.name, default: []].append(dept)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted { ($0.teams?.count ?? 0) > ($1.teams?.count ?? 0) }
        let canonical = ranked[0]
        for duplicate in ranked.dropFirst() {
            if canonical.organization == nil { canonical.organization = duplicate.organization }
            for team in duplicate.teams ?? [] { team.department = canonical }
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate department record(s)")
    }
}

/// Removes duplicate ``DependabotAlert`` records for the same repository and alert number.
///
/// CloudKit sync can materialise multiple copies of the same logical alert with different
/// `PersistentIdentifier` values. For each duplicate group the record with the most populated
/// fields (non-nil `fixedAt`, `dismissedAt`, etc.) is kept; the rest are deleted.
@MainActor
private func deduplicateDependabotAlerts(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<DependabotAlert>()) else { return }

    var groups: [String: [DependabotAlert]] = [:]
    for alert in all {
        let repoKey = "\(alert.repository?.owner ?? "")/\(alert.repository?.name ?? "")"
        groups["\(repoKey):\(alert.alertNumber)", default: []].append(alert)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted { dependabotAlertRichness($0) > dependabotAlertRichness($1) }
        for duplicate in ranked.dropFirst() {
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate Dependabot alert record(s)")
    }
}

/// Returns a richness score for a Dependabot alert based on how many optional fields are populated.
private func dependabotAlertRichness(_ alert: DependabotAlert) -> Int {
    (alert.fixedAt != nil ? 1 : 0)
    + (alert.dismissedAt != nil ? 1 : 0)
    + (alert.autoDismissedAt != nil ? 1 : 0)
    + (alert.cveId != nil ? 1 : 0)
    + (alert.fixVersion != nil ? 1 : 0)
}

/// Removes duplicate ``CodeScanningAlert`` records for the same repository and alert number.
///
/// CloudKit sync can materialise multiple copies of the same logical alert. For each duplicate
/// group the record with the most populated optional fields is kept; the rest are deleted.
@MainActor
private func deduplicateCodeScanningAlerts(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<CodeScanningAlert>()) else { return }

    var groups: [String: [CodeScanningAlert]] = [:]
    for alert in all {
        let repoKey = "\(alert.repository?.owner ?? "")/\(alert.repository?.name ?? "")"
        groups["\(repoKey):\(alert.alertNumber)", default: []].append(alert)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted { codeScanningAlertRichness($0) > codeScanningAlertRichness($1) }
        for duplicate in ranked.dropFirst() {
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate code scanning alert record(s)")
    }
}

/// Returns a richness score for a code scanning alert based on how many optional fields are populated.
private func codeScanningAlertRichness(_ alert: CodeScanningAlert) -> Int {
    (alert.fixedAt != nil ? 1 : 0)
    + (alert.dismissedAt != nil ? 1 : 0)
    + (alert.locationPath != nil ? 1 : 0)
    + (alert.messageText != nil ? 1 : 0)
    + (alert.securitySeverityLevel != nil ? 1 : 0)
}

/// Removes duplicate ``SecretScanningAlert`` records for the same repository and alert number.
///
/// CloudKit sync can materialise multiple copies of the same logical alert. For each duplicate
/// group the record with the most populated optional fields is kept; the rest are deleted.
@MainActor
private func deduplicateSecretScanningAlerts(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<SecretScanningAlert>()) else { return }

    var groups: [String: [SecretScanningAlert]] = [:]
    for alert in all {
        let repoKey = "\(alert.repository?.owner ?? "")/\(alert.repository?.name ?? "")"
        groups["\(repoKey):\(alert.alertNumber)", default: []].append(alert)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted { secretScanningAlertRichness($0) > secretScanningAlertRichness($1) }
        for duplicate in ranked.dropFirst() {
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate secret scanning alert record(s)")
    }
}

/// Returns a richness score for a secret scanning alert based on how many optional fields are populated.
private func secretScanningAlertRichness(_ alert: SecretScanningAlert) -> Int {
    (alert.resolvedAt != nil ? 1 : 0)
    + (alert.resolution != nil ? 1 : 0)
}

/// Removes duplicate ``OpenPullRequest`` records for the same repository and PR number.
///
/// CloudKit sync can materialise multiple copies of the same logical PR. For each duplicate
/// group the most recently-created record is kept; the rest are deleted.
@MainActor
private func deduplicateOpenPullRequests(in context: ModelContext) {
    guard let all = try? context.fetch(FetchDescriptor<OpenPullRequest>()) else { return }

    var groups: [String: [OpenPullRequest]] = [:]
    for pr in all {
        let repoKey = "\(pr.repository?.owner ?? "")/\(pr.repository?.name ?? "")"
        groups["\(repoKey):\(pr.number)", default: []].append(pr)
    }

    var deletedCount = 0
    for group in groups.values where group.count > 1 {
        let ranked = group.sorted { $0.createdAt > $1.createdAt }
        for duplicate in ranked.dropFirst() {
            context.delete(duplicate)
            deletedCount += 1
        }
    }

    if deletedCount > 0 {
        try? context.save()
        print("[Focus] 🧹 Removed \(deletedCount) duplicate open PR record(s)")
    }
}

// MARK: - ModelContainer

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
        SavedRelease.self,
        SavedBranch.self,
    ]

    let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
    // swiftlint:disable:next force_try
    return try! ModelContainer(for: Schema(allTypes), configurations: config)
}
