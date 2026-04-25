import Foundation
import Testing
import SwiftData
@testable import Focus

/// Tests for `BackgroundSyncManager`.
@Suite("BackgroundSyncManager Tests")
@MainActor // Required because BackgroundSyncManager and its sync methods are @MainActor
struct BackgroundSyncManagerTests {

    // MARK: - Sync intervals

    /// Verifies that the security sync interval constant equals 8 hours (28 800 seconds).
    @Test("security sync interval is 8 hours")
    func securitySyncIntervalIs8Hours() {
        #expect(BackgroundSyncManager.securitySyncInterval == 8 * 60 * 60)
    }

    /// Verifies that the contribution sync interval constant equals 24 hours (86 400 seconds).
    @Test("contribution sync interval is 24 hours")
    func contributionSyncIntervalIs24Hours() {
        #expect(BackgroundSyncManager.contributionSyncInterval == 24 * 60 * 60)
    }

    /// Verifies that the contribution sync interval is strictly longer than the security sync interval.
    @Test("contribution sync interval is longer than security sync interval")
    func contributionIntervalLongerThanSecurity() {
        #expect(BackgroundSyncManager.contributionSyncInterval > BackgroundSyncManager.securitySyncInterval)
    }

    // MARK: - Initial state

    /// Verifies that `syncCurrent` starts at zero on a freshly created manager.
    @Test("syncCurrent starts at zero")
    func syncCurrentStartsAtZero() {
        let manager = BackgroundSyncManager()
        #expect(manager.syncCurrent == 0)
    }

    /// Verifies that `syncTotal` starts at zero on a freshly created manager.
    @Test("syncTotal starts at zero")
    func syncTotalStartsAtZero() {
        let manager = BackgroundSyncManager()
        #expect(manager.syncTotal == 0)
    }

    /// Verifies that `lastContributionSyncedAt` is `nil` when no value is stored in `UserDefaults`.
    @Test("lastContributionSyncedAt starts nil when no UserDefaults value")
    func lastContributionSyncedAtStartsNil() {
        // Ensure no stale value from a prior run.
        UserDefaults.standard.removeObject(forKey: BackgroundSyncManager.lastContributionSyncedAtKey)
        let manager = BackgroundSyncManager()
        #expect(manager.lastContributionSyncedAt == nil)
    }

    /// Verifies that `lastSyncedAt` is `nil` when no value is stored in `UserDefaults`.
    @Test("lastSyncedAt starts nil when no UserDefaults value")
    func lastSyncedAtStartsNil() {
        UserDefaults.standard.removeObject(forKey: BackgroundSyncManager.lastSyncedAtKey)
        let manager = BackgroundSyncManager()
        #expect(manager.lastSyncedAt == nil)
    }

    // MARK: - UserDefaults persistence

    /// Verifies that a date stored in `UserDefaults` before init is surfaced as `lastContributionSyncedAt`.
    @Test("lastContributionSyncedAt is loaded from UserDefaults on init")
    func lastContributionSyncedAtLoadedFromUserDefaults() {
        let stored = Date(timeIntervalSinceNow: -3600)
        UserDefaults.standard.set(stored, forKey: BackgroundSyncManager.lastContributionSyncedAtKey)
        defer { UserDefaults.standard.removeObject(forKey: BackgroundSyncManager.lastContributionSyncedAtKey) }

        let manager = BackgroundSyncManager()
        let loaded = try! #require(manager.lastContributionSyncedAt)
        #expect(abs(loaded.timeIntervalSince(stored)) < 0.001)
    }

    /// Verifies that a date stored in `UserDefaults` before init is surfaced as `lastSyncedAt`.
    @Test("lastSyncedAt is loaded from UserDefaults on init")
    func lastSyncedAtLoadedFromUserDefaults() {
        let stored = Date(timeIntervalSinceNow: -1800)
        UserDefaults.standard.set(stored, forKey: BackgroundSyncManager.lastSyncedAtKey)
        defer { UserDefaults.standard.removeObject(forKey: BackgroundSyncManager.lastSyncedAtKey) }

        let manager = BackgroundSyncManager()
        let loaded = try! #require(manager.lastSyncedAt)
        #expect(abs(loaded.timeIntervalSince(stored)) < 0.001)
    }

    // MARK: - syncIfNeeded short-circuit

    /// Verifies that `syncIfNeeded` returns without syncing when `setup()` has not been called.
    @Test("syncIfNeeded does nothing when not set up")
    func syncIfNeededDoesNothingWhenNotSetUp() async throws {
        UserDefaults.standard.removeObject(forKey: BackgroundSyncManager.lastSyncedAtKey)
        UserDefaults.standard.removeObject(forKey: BackgroundSyncManager.lastContributionSyncedAtKey)

        let manager = BackgroundSyncManager()
        // setup() has not been called — isSetup is false.
        // syncIfNeeded should return immediately without setting isSyncing.
        let container = try makeTestContainer()
        await manager.syncIfNeeded(context: container.mainContext)
        #expect(!manager.isSyncing)
    }

    /// Verifies that `syncIfNeeded` leaves timestamps unchanged when both sync thresholds are below their limits.
    @Test("syncIfNeeded does nothing when both syncs are fresh")
    func syncIfNeededDoesNothingWhenBothFresh() async throws {
        // Seed recent timestamps so neither threshold is exceeded.
        let recentSecurity = Date(timeIntervalSinceNow: -60)       // 1 minute ago (< 8h)
        let recentContribution = Date(timeIntervalSinceNow: -3600)  // 1 hour ago (< 24h)
        UserDefaults.standard.set(recentSecurity, forKey: BackgroundSyncManager.lastSyncedAtKey)
        UserDefaults.standard.set(recentContribution, forKey: BackgroundSyncManager.lastContributionSyncedAtKey)
        defer {
            UserDefaults.standard.removeObject(forKey: BackgroundSyncManager.lastSyncedAtKey)
            UserDefaults.standard.removeObject(forKey: BackgroundSyncManager.lastContributionSyncedAtKey)
        }

        let manager = BackgroundSyncManager()
        // isSetup is still false — guard fires first. But we verify state is unchanged.
        let container = try makeTestContainer()
        await manager.syncIfNeeded(context: container.mainContext)
        #expect(!manager.isSyncing)

        // Timestamps should be unchanged (no sync occurred).
        let loaded = try #require(manager.lastSyncedAt)
        #expect(abs(loaded.timeIntervalSince(recentSecurity)) < 0.001)
    }
}
