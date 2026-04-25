import Foundation
import SwiftData
import Observation

// MARK: - BriefingLoadingPhase

/// A discrete stage in the brief generation pipeline, surfaced to the UI as loading feedback.
enum BriefingLoadingPhase: Equatable, Sendable {
    case loadingData
    case fetchingMetrics
    case fetchingSecurityAlerts
    case assembling

    var label: String {
        switch self {
        case .loadingData:           return "Reading local data…"
        case .fetchingMetrics:       return "Fetching PR metrics from GitHub…"
        case .fetchingSecurityAlerts: return "Fetching security data…"
        case .assembling:            return "Assembling your briefing…"
        }
    }
}

// MARK: - BriefingManager

/// Caches the weekly ``Briefing`` so the Focus tab renders instantly on revisit.
///
/// Each (previous-calendar-week, scope) pair is cached independently. A cached entry
/// stays valid for the full week it covers — when Monday arrives the cache key changes
/// and the next `load` call triggers fresh generation automatically.
///
/// Inject one instance from `FocusApp` and read it in ``BriefingView``.
@Observable
@MainActor
final class BriefingManager {

    // MARK: - State

    /// Briefings keyed by "yyyy-MM-dd_scopeDisplayName".
    private var cache: [String: Briefing] = [:]

    /// Cache keys for which generation is currently in flight.
    private var loadingKeys: Set<String> = []

    /// Current loading phase per cache key, cleared when generation completes.
    private var loadingPhases: [String: BriefingLoadingPhase] = [:]

    // MARK: - Public Interface

    /// The cached briefing for the given scope, or `nil` if not yet generated.
    func briefing(for scope: BriefingScope) -> Briefing? {
        cache[cacheKey(for: scope)]
    }

    /// Whether generation is currently in flight for the given scope.
    func isLoading(for scope: BriefingScope) -> Bool {
        loadingKeys.contains(cacheKey(for: scope))
    }

    /// The current loading phase for the given scope, or `nil` if not loading.
    func loadingPhase(for scope: BriefingScope) -> BriefingLoadingPhase? {
        loadingPhases[cacheKey(for: scope)]
    }

    /// Generates the briefing for `scope` if it is not already cached or in flight.
    ///
    /// Safe to call on every view appear — it no-ops immediately when a cached result exists.
    func load(scope: BriefingScope, service: BriefingService, context: ModelContext) async {
        let key = cacheKey(for: scope)
        guard cache[key] == nil, !loadingKeys.contains(key) else { return }
        await perform(key: key, scope: scope, service: service, context: context)
    }

    /// Discards the cached briefing for `scope` and regenerates it.
    func refresh(scope: BriefingScope, service: BriefingService, context: ModelContext) async {
        let key = cacheKey(for: scope)
        cache.removeValue(forKey: key)
        await perform(key: key, scope: scope, service: service, context: context)
    }

    // MARK: - Private

    private func perform(
        key: String,
        scope: BriefingScope,
        service: BriefingService,
        context: ModelContext
    ) async {
        loadingKeys.insert(key)
        let result = await service.generate(scope: scope, in: context) { [weak self] phase in
            self?.loadingPhases[key] = phase
        }
        cache[key] = result
        loadingKeys.remove(key)
        loadingPhases.removeValue(forKey: key)
    }

    /// Returns a stable cache key for the given scope within the current briefing week.
    ///
    /// The key encodes the previous week's Monday so it naturally expires when the calendar
    /// rolls over to a new week — no explicit invalidation needed.
    private func cacheKey(for scope: BriefingScope) -> String {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard
            let lastWeekDate = cal.date(byAdding: .weekOfYear, value: -1, to: Date()),
            let interval = cal.dateInterval(of: .weekOfYear, for: lastWeekDate)
        else {
            return "unknown_\(scope.displayName)"
        }
        return "\(fmt.string(from: interval.start))_\(scope.displayName)"
    }
}
