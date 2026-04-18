import SwiftUI

// MARK: - BriefingAvatarView

/// A flat initials-only circular avatar used inside briefing rows.
///
/// `BriefingAvatarView` does not load remote images — it always renders the
/// supplied initials over a paper-toned circle. Used inside contributor and
/// blocked-member rows where a fast, lightweight avatar is preferred.
struct BriefingAvatarView: View {

    // MARK: - Properties

    /// The initials text rendered inside the circle.
    let initials: String

    /// The diameter of the avatar circle in points. Defaults to `32`.
    var size: CGFloat = 32

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Circle()
            .fill(BriefingColor.paper3)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(BriefingFont.meta)
                    .foregroundStyle(BriefingColor.ink2)
            )
            .clipShape(Circle())
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        BriefingAvatarView(initials: "AL")
        BriefingAvatarView(initials: "DM", size: 40)
    }
    .padding()
}
