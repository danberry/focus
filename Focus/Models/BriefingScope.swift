import Foundation

// MARK: - BriefingScope

/// A filter that narrows the weekly ``Briefing`` to a subset of the data graph.
///
/// `BriefingScope` is consumed by ``BriefingService/generate(scope:in:)`` to
/// restrict the set of ``SavedRepository`` and ``Member`` records aggregated
/// into the briefing. The ``BriefingView`` toolbar exposes a picker that lets
/// the reader pivot between an all-encompassing view and a team, department,
/// or organization slice.
///
/// The enum deliberately does not conform to `Sendable` or `Equatable`:
/// SwiftData `@Model` associated values don't satisfy those protocols cleanly.
/// All use of `BriefingScope` is confined to `@MainActor` contexts.
enum BriefingScope {

    /// All saved repositories and members are included.
    case all

    /// Only repositories and members associated with the specified ``Team`` are included.
    case team(Team)

    /// Only repositories and members whose team rolls up to the specified ``Department`` are included.
    case department(Department)

    /// Only repositories and members belonging to the specified ``SavedOrganization`` are included.
    case organization(SavedOrganization)

    // MARK: - Display

    /// A short, human-readable label suitable for display in the scope picker.
    ///
    /// For the organization case, the organization's display `name` is preferred; if `nil`,
    /// the `login` handle is used as a fallback.
    var displayName: String {
        switch self {
        case .all:                    return "All"
        case .team(let t):            return t.name
        case .department(let d):      return d.name
        case .organization(let o):    return o.name ?? o.login
        }
    }
}
