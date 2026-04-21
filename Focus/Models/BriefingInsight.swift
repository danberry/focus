import Foundation

// MARK: - BriefingDomain

/// The domain of an engineering insight.
///
/// One case per insight-generator family. Domains are stable identifiers used by the
/// aggregator to select insights across multiple generators.
enum BriefingDomain: String, Sendable, CaseIterable {

    /// Security-debt insights (Dependabot, code scanning, secret scanning).
    case security

    /// Shipping velocity and PR-flow insights.
    case shipping

    /// Blocked or idle member insights.
    case blocked

    /// Release cadence and deploy insights.
    case releases
}

// MARK: - BriefingInsightPriority

/// Shared priority tier used to rank insights across every domain.
///
/// Lower `rawValue` = higher priority. The aggregator compares priorities across
/// domains to choose which insight surfaces in each attention slot.
enum BriefingInsightPriority: Int, Comparable, Sendable {

    /// Immediate action required — e.g. public credential leak, push protection bypass.
    case p0_immediate = 0

    /// Urgent — e.g. aging unassigned criticals, CVSS ≥ 9, multi-repo spread.
    case p1_urgent = 1

    /// Notable — e.g. growing trend, blast radius, SLA breach.
    case p2_notable = 2

    /// Positive — e.g. cleared criticals, streak, fixes available.
    case p3_positive = 3

    /// Informational — low-stakes observations.
    case p4_informational = 4

    /// Orders priorities so that higher urgency (lower rawValue) compares as `<`.
    static func < (lhs: BriefingInsightPriority, rhs: BriefingInsightPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - BriefingInsight

/// The shared output type produced by every domain generator.
///
/// `BriefingInsight` is a display-ready payload, decoupled from any domain-specific
/// kind enum. The aggregator consumes these directly to build attention cards without
/// needing to know which generator produced them.
struct BriefingInsight: Sendable, Hashable {

    /// The domain that produced this insight.
    let domain: BriefingDomain

    /// Cross-domain ranking priority.
    let priority: BriefingInsightPriority

    /// The semantic tone used to render the attention card.
    let tone: BriefingTone

    /// The primary title sentence (may include Markdown emphasis like `**bold**`).
    let title: String

    /// The supporting meta line shown beneath the title.
    let meta: String

    /// The action button label (typically ends with `"→"`).
    let actionLabel: String
}
