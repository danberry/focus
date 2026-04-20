import SwiftUI

// MARK: - BriefingAvatarView

/// A circular avatar used inside briefing rows.
///
/// When `githubLogin` is provided the view attempts to load the member's GitHub
/// avatar via `AsyncImage`. The initials circle is shown while loading and as a
/// permanent fallback when no login is available or the image fails to load.
struct BriefingAvatarView: View {

    // MARK: - Properties

    /// The initials text rendered inside the fallback circle.
    let initials: String

    /// The GitHub login used to construct the avatar URL. When `nil` the view
    /// renders the initials circle only.
    var githubLogin: String? = nil

    /// The diameter of the avatar circle in points. Defaults to `32`.
    var size: CGFloat = 32

    // MARK: - Body

    /// The view's content.
    var body: some View {
        if let login = githubLogin,
           let url = URL(string: "https://avatars.githubusercontent.com/\(login)?s=72") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                default:
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }

    // MARK: - Helpers

    private var initialsCircle: some View {
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
        BriefingAvatarView(initials: "DM", githubLogin: "danberry", size: 40)
    }
    .padding()
}
