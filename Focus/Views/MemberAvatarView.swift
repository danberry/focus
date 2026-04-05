import SwiftUI
import SwiftData

// MARK: - MemberAvatarView

struct MemberAvatarView: View {
    let member: Member

    private let size: CGFloat = 36

    var body: some View {
        if let githubId = member.githubId {
            avatarImage(githubId: githubId)
        } else {
            initialsCircle
        }
    }

    // MARK: - Private

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
