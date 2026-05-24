import SwiftUI

// MARK: - DossierAllOpenPRsView

/// A full list of all open pull requests for a repository, navigated to from the dossier.
///
/// Accepts the lightweight ``RepositoryDossier/OpenPR`` value type so it can be driven
/// directly from the dossier without reaching back into SwiftData.
struct DossierAllOpenPRsView: View {

    // MARK: - Properties

    /// All open pull requests, ordered newest first.
    let openPRs: [RepositoryDossier.OpenPR]

    /// The repository display name used as the navigation title.
    let repoDisplayName: String

    // MARK: - Body

    var body: some View {
        List {
            if openPRs.isEmpty {
                Text("No open pull requests")
                    .font(BriefingFont.body)
                    .foregroundStyle(BriefingColor.ink3)
            } else {
                ForEach(openPRs) { pr in
                    prRow(pr)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Open Pull Requests")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func prRow(_ pr: RepositoryDossier.OpenPR) -> some View {
        let ageDays = Int(Date().timeIntervalSince(pr.createdAt) / 86_400)
        let isStale = ageDays >= 30
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(pr.id, format: .number.grouping(.never))")
                    .font(BriefingFont.meta)
                    .foregroundStyle(
                        isStale ? .customYellow : BriefingColor.ink3
                    )
                Spacer()
                Text(ageString(from: pr.createdAt))
                    .font(BriefingFont.meta)
                    .foregroundStyle(
                        isStale ? .customYellow : BriefingColor.ink3
                    )
            }
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: "https://github.com/\(pr.authorLogin).png?size=44")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Text(loginInitials(pr.authorLogin))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(BriefingColor.ink2)
                }
                .frame(width: 22, height: 22)
                .background(BriefingColor.paper3, in: Circle())
                .clipShape(Circle())
                Text(pr.title)
                    .font(BriefingFont.body)
                    .foregroundStyle(BriefingColor.ink)
                    .lineLimit(2)
            }
        }
    }
    
    /// Derives two-letter initials from a GitHub login (e.g. `"jordan-m"` → `"JM"`).
    private func loginInitials(_ login: String) -> String {
        let parts = login.split(separator: "-").map { String($0.prefix(1)).uppercased() }
        return parts.count >= 2 ? parts.prefix(2).joined() : String(login.prefix(2)).uppercased()
    }

    private func ageString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3_600)
        if hours < 24 { return "\(max(1, hours))h" }
        return "\(hours / 24)d"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DossierAllOpenPRsView(
            openPRs: RepositoryDossier.preview.openPRs,
            repoDisplayName: RepositoryDossier.preview.displayName
        )
    }
}
