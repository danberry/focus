import SwiftUI

// MARK: - BriefingBlockedSection

/// The "Inactive Members" section — three summary cards covering unlinked accounts,
/// members idle this week, and members idle for more than a week.
struct BriefingBlockedSection: View {

    // MARK: - Properties

    /// The "Who Looks Blocked" section payload.
    let blocked: BriefingBlocked

    /// Optional closure invoked when the DM pill is tapped on a member's card.
    var onDM: ((BriefingBlockedMember) -> Void)? = nil

    /// Optional closure invoked when the Open pill is tapped on a member's card.
    var onOpen: ((BriefingBlockedMember) -> Void)? = nil

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: BriefingLayout.sectionGap) {

            // MARK: Section header
            SectionHeaderView(
                number: "02",
                verdict: blocked.verdict,
                summary: blocked.summary
            )

            // MARK: Category cards
            HStack(spacing: 10) {
                InactiveCategoryCard(
                    title: "No GitHub linked",
                    subtitle: "No contribution history detected",
                    members: blocked.unlinked,
                    tone: .red
                )

                InactiveCategoryCard(
                    title: "No contributions this week",
                    subtitle: "Idle for up to one week",
                    members: blocked.idleThisWeek,
                    tone: .blue
                )

                InactiveCategoryCard(
                    title: "No contributions for 1+ week",
                    subtitle: "Missing for more than a week",
                    members: blocked.idleLongTerm,
                    tone: .red
                )
            }
        }
    }
}

// MARK: - InactiveCategoryCard

/// A summary card for one inactivity category in the "Inactive Members" section.
private struct InactiveCategoryCard: View {

    // MARK: - Properties

    /// The category label shown as the card title.
    let title: String

    /// A short description shown when the category has no members.
    let subtitle: String

    /// The members flagged in this category.
    let members: [BriefingBlockedMember]

    /// The semantic tone that drives the card's color when members are present.
    let tone: BriefingTone

    // MARK: - Helpers

    private var isEmpty: Bool { members.isEmpty }

    private var toneColor: Color {
        switch tone {
        case .red: return BriefingColor.red2
        case .blue: return BriefingColor.blue2
        case .neutral: return BriefingColor.ink2
        }
    }

    /// Up to three member names followed by an overflow count if needed, e.g. "Alice, Bob, +2 more".
    private var namesSummary: String {
        let visible = members.prefix(3).map(\.name)
        let overflow = members.count - visible.count
        var parts = Array(visible)
        if overflow > 0 { parts.append("+\(overflow) more") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isEmpty ? "—" : "\(members.count)")
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .foregroundStyle(isEmpty ? Color.gray400 : Color.gray700)

            Text(title)
                .font(BriefingFont.attentionTitle)
                .foregroundStyle(BriefingColor.ink)

            Text(isEmpty ? subtitle : namesSummary)
                .font(BriefingFont.meta)
                .foregroundStyle(isEmpty ? BriefingColor.ink3 : toneColor)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .briefingCard(tone: isEmpty ? .neutral : tone)
    }
}

// MARK: - Preview

#Preview {
    BriefingBlockedSection(blocked: Briefing.placeholder.blocked)
        .padding(.vertical)
}
