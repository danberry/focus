import SwiftUI
import SwiftData

// MARK: - MemberAvatarView

/// Displays a member's GitHub avatar, falling back to an initials circle when no GitHub ID is set.
struct MemberAvatarView: View {

    // MARK: - Properties

    /// The member whose avatar this view displays.
    let member: Member

    /// The diameter of the avatar circle in points.
    private let size: CGFloat = 36

    // MARK: - Body

    /// The view's content.
    var body: some View {
        if let githubId = member.githubId {
            avatarImage(githubId: githubId)
        } else {
            initialsCircle
        }
    }

    // MARK: - Helpers

    /// Returns an async-loaded GitHub avatar image for the given user ID.
    private func avatarImage(githubId: Int) -> some View {
        let url = URL(string: "https://avatars.githubusercontent.com/u/\(githubId)")
        return AsyncImage(url: url) { phase in
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

    /// A circle filled with accent color displaying the member's initials.
    private var initialsCircle: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            )
    }

    /// The one- or two-character initials derived from the member's name.
    private var initials: String {
        let parts = member.name
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .map { String($0) }
        switch parts.count {
        case 0:
            return "?"
        case 1:
            return String(parts[0].prefix(1)).uppercased()
        default:
            return (String(parts[0].prefix(1)) + String(parts[parts.count - 1].prefix(1))).uppercased()
        }
    }
}
