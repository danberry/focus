import SwiftUI

// MARK: - OrgAvatarView

/// Displays a GitHub organization's avatar, falling back to an initials circle when no avatar URL is available.
struct OrgAvatarView: View {

    // MARK: - Properties

    /// The organization whose avatar this view displays.
    let organization: SavedOrganization

    /// The diameter of the avatar circle in points.
    private let size: CGFloat = 36

    // MARK: - Body

    /// The view's content.
    var body: some View {
        if let urlString = organization.avatarUrl, let url = URL(string: urlString) {
            avatarImage(url: url)
        } else {
            initialsCircle
        }
    }

    // MARK: - Helpers

    /// Returns an async-loaded avatar image for the given URL.
    private func avatarImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            case .failure, .empty:
                initialsCircle
            @unknown default:
                initialsCircle
            }
        }
        .frame(width: size, height: size)
    }

    /// A circle filled with accent color displaying the organization's first login character.
    private var initialsCircle: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            )
    }

    /// The single uppercase character derived from the organization's login.
    private var initial: String {
        String(organization.login.prefix(1)).uppercased()
    }
}
