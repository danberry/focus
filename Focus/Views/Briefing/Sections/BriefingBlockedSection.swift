import SwiftUI

// MARK: - BriefingBlockedSection

/// The "Who Looks Blocked" section — quiet or stuck members with quick actions.
///
/// Renders a section header above one card per blocked member. Each card carries
/// avatar initials, team and idle metadata, an italic recommendation, and two
/// pill buttons that surface the DM and Open actions.
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

            // MARK: Member cards
            VStack(spacing: 10) {
                ForEach(Array(blocked.members.enumerated()), id: \.offset) { _, member in
                    BlockedMemberCard(
                        member: member,
                        onDM: { onDM?(member) },
                        onOpen: { onOpen?(member) }
                    )
                }
            }
        }
    }
}

// MARK: - BlockedMemberCard

/// A single blocked-member card inside the "Who Looks Blocked" section.
private struct BlockedMemberCard: View {

    // MARK: - Properties

    /// The blocked member payload to render.
    let member: BriefingBlockedMember

    /// Closure invoked when the DM pill button is tapped.
    let onDM: () -> Void

    /// Closure invoked when the Open pill button is tapped.
    let onOpen: () -> Void

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                BriefingAvatarView(initials: member.initials, githubLogin: member.githubLogin, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(BriefingFont.attentionTitle)
                        .foregroundStyle(BriefingColor.ink)

                    Text(member.neverContributed ? "\(member.team) · no contributions on record" : "\(member.team) · \(member.idleLabel) idle")
                        .font(BriefingFont.meta)
                        .foregroundStyle(BriefingColor.ink3)
                }

                Spacer()
            }

            Text(member.recommendation)
                .font(BriefingFont.body)
                .foregroundStyle(BriefingColor.ink3)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button("DM", action: onDM)
                    .buttonStyle(BlockedPillButtonStyle())

                Button("Open", action: onOpen)
                    .buttonStyle(BlockedPillButtonStyle())
            }
        }
        .padding(14)
        .briefingCard(tone: member.neverContributed ? .red : (member.urgent ? .blue : .neutral))
    }
}

// MARK: - BlockedPillButtonStyle

/// A capsule pill style used by the blocked-member card's quick action buttons.
private struct BlockedPillButtonStyle: ButtonStyle {

    // MARK: - Body

    /// Builds the styled button label.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BriefingFont.meta)
            .foregroundStyle(BriefingColor.ink2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(BriefingColor.paper3))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Preview

#Preview {
    BriefingBlockedSection(blocked: Briefing.placeholder.blocked)
        .padding(.vertical)
}
