import SwiftUI
import SwiftData

// MARK: - MergedPRsYesterdayView

struct MergedPRsYesterdayView: View {
    @Environment(AuthenticationService.self) private var authService
    @Query(sort: \SavedRepository.displayName) private var savedRepositories: [SavedRepository]
    @Query(sort: \Member.name) private var members: [Member]

    @State private var isLoading = false
    @State private var error: GitHubError?
    @State private var allPRs: [MergedPR] = []

    private var yesterday: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(byAdding: .day, value: -1, to: Date())!
    }

    private var navigationSubtitle: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .none
        return fmt.string(from: yesterday)
    }

    private var loginToTeamName: [String: String] {
        Dictionary(
            uniqueKeysWithValues: members.compactMap { member in
                guard let login = member.githubLogin, let team = member.team else { return nil }
                return (login.lowercased(), team.name)
            }
        )
    }

    private var teamSections: [(teamName: String, prs: [MergedPR])] {
        var grouped: [String: [MergedPR]] = [:]
        for pr in allPRs {
            let teamName = loginToTeamName[pr.authorLogin.lowercased()] ?? "No Team"
            grouped[teamName, default: []].append(pr)
        }
        return grouped
            .map { (teamName: $0.key, prs: $0.value.sorted { $0.mergedAt < $1.mergedAt }) }
            .sorted {
                if $0.teamName == "No Team" { return false }
                if $1.teamName == "No Team" { return true }
                return $0.teamName < $1.teamName
            }
    }

    var body: some View {
        Group {
            if isLoading && allPRs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView(
                    "Unable to Load Report",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else if allPRs.isEmpty {
                ContentUnavailableView(
                    "No Merged PRs",
                    systemImage: "checkmark.circle",
                    description: Text("No pull requests were merged yesterday across your saved repositories.")
                )
            } else {
                List {
                    Section {
                        MergedPRsHeroRow(totalCount: allPRs.count)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                    ForEach(teamSections, id: \.teamName) { section in
                        NavigationLink(destination: TeamMergedPRsListView(teamName: section.teamName, prs: section.prs)) {
                            LabeledContent(section.teamName) {
                                Text("\(section.prs.count)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await loadData() }
            }
        }
        .navigationTitle("Merged PRs")
        .navigationSubtitle(navigationSubtitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Private

    @MainActor
    private func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        let service = MergedPRReportService(
            graphQL: GraphQLClient(tokenProvider: authService.tokenProvider)
        )

        do {
            let repos = savedRepositories.map { (owner: $0.owner, name: $0.name) }
            let prsByRepo = try await service.fetchMergedPRs(for: repos, on: yesterday)
            allPRs = prsByRepo.values.flatMap { $0 }
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }
}

// MARK: - TeamMergedPRsListView

private struct TeamMergedPRsListView: View {
    @Environment(\.openURL) private var openURL

    let teamName: String
    let prs: [MergedPR]

    var body: some View {
        List(prs) { pr in
            Button {
                if let url = URL(string: pr.url) {
                    openURL(url)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pr.title)
                        .lineLimit(1)
                        .foregroundStyle(Color.primary)
                    Text("by @\(pr.authorLogin) • #\(pr.number)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .navigationTitle(teamName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - MergedPRsHeroRow

private struct MergedPRsHeroRow: View {
    let totalCount: Int

    var body: some View {
        LabeledContent {} label: {
            Text("\(totalCount)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text("MERGED PRS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(1.2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 26))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
