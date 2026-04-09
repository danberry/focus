import SwiftUI
import SwiftData

// MARK: - MergedPRsTodayView

struct MergedPRsTodayView: View {
    @Environment(AuthenticationService.self) private var authService
    @Query(sort: \SavedRepository.displayName) private var savedRepositories: [SavedRepository]

    @State private var isLoading = false
    @State private var error: GitHubError?
    @State private var prsByRepo: [String: [MergedPR]] = [:]

    private var allPRs: [MergedPR] { prsByRepo.values.flatMap { $0 } }

    private var today: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.startOfDay(for: Date())
    }

    private var dateSubtitle: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .none
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: today)
    }

    private var displayNameByRepo: [String: String] {
        Dictionary(uniqueKeysWithValues: savedRepositories.map { ("\($0.owner)/\($0.name)".lowercased(), $0.displayName) })
    }

    private var repoSections: [(repoName: String, prs: [MergedPR])] {
        let lookup = displayNameByRepo
        return prsByRepo
            .map { (repoName: lookup[$0.key.lowercased()] ?? $0.key, prs: $0.value.sorted { $0.mergedAt < $1.mergedAt }) }
            .sorted { $0.repoName < $1.repoName }
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
                    description: Text("No pull requests have been merged today across your saved repositories.")
                )
            } else {
                List {
                    Section {
                        MergedPRsHeroRow(totalCount: allPRs.count, subtitle: dateSubtitle)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listSectionSpacing(18)
                    ForEach(repoSections, id: \.repoName) { section in
                        NavigationLink(destination: RepoMergedPRsListView(repoName: section.repoName, prs: section.prs)) {
                            LabeledContent(section.repoName) {
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
            prsByRepo = try await service.fetchMergedPRs(for: repos, on: today)
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }
}

// MARK: - RepoMergedPRsListView

private struct RepoMergedPRsListView: View {
    @Environment(\.openURL) private var openURL

    let repoName: String
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
        .navigationTitle(repoName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - MergedPRsHeroRow

private struct MergedPRsHeroRow: View {
    let totalCount: Int
    let subtitle: String

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
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 26))
    }
}
