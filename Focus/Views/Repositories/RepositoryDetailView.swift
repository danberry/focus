import SwiftUI
import SwiftData

// MARK: - RepositoryDetailView

/// Displays velocity, pull requests, code owners, and security alerts for a saved repository.
struct RepositoryDetailView: View {

    // MARK: - Properties

    /// The repository whose detail data this view displays.
    @Bindable var repository: SavedRepository

    /// All teams, used to populate the ownership picker.
    @Query(sort: [SortDescriptor(\Team.name, comparator: .localizedStandard)]) private var teams: [Team]

    /// The authentication service, used to build the REST client for refresh.
    @Environment(AuthenticationService.self) private var authService

    /// The SwiftData model context, used when persisting refreshed alerts.
    @Environment(\.modelContext) private var modelContext

    /// The currently selected velocity period, controlling which metric is shown in the hero row.
    @State private var selectedPeriod: VelocityPeriod = .yearToDate

    // MARK: - Body

    /// The view's content.
    var body: some View {
        List {
            // MARK: Velocity

            Section {
                let record = (repository.velocityMetrics ?? []).first { $0.periodType == selectedPeriod.rawValue }

                if let record {
                    VelocityHeroRow(comparison: record.comparison)
                        .listRowSeparator(.hidden)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("—")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.quaternary)
                            Text("Not yet synced")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                }
            } header: {
                HStack {
                    Text("Velocity")
                    Menu {
                        ForEach(VelocityPeriod.allCases, id: \.self) { period in
                            Button {
                                selectedPeriod = period
                            } label: {
                                Label(period.rawValue, systemImage: selectedPeriod == period ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
            }

            // MARK: Open Pull Requests

            let sortedPRs = (repository.openPullRequests ?? []).sorted { $0.createdAt < $1.createdAt }
            Section("Open Pull Requests") {
                if sortedPRs.isEmpty {
                    Text("No open pull requests")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPRs.prefix(6)) { pr in
                        NavigationLink(destination: PullRequestDetailView(pullRequest: pr)) {
                            LabeledContent {
                            } label: {
                                Text(pr.title)
                                    .lineLimit(1)
                                Text(daysOpenLabel(pr.createdAt))
                            }
                        }
                    }
                    if sortedPRs.count > 6 {
                        NavigationLink("Show all \(sortedPRs.count) pull requests") {
                            AllPullRequestsView(pullRequests: sortedPRs)
                        }
                        .foregroundStyle(.tint)
                    }
                }
            }

            // MARK: Codeowners

            Section("Code Owners") {
                let uniqueHandles = Array(Set((repository.codeowners ?? []).map(\.handle))).sorted()
                if uniqueHandles.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(uniqueHandles, id: \.self) { handle in
                        let isTeam = handle.contains("/")
                        let raw = handle.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
                        let displayHandle = isTeam ? (raw.split(separator: "/").last.map(String.init) ?? raw) : raw
                        LabeledContent(isTeam ? "Team" : "User", value: displayHandle)
                    }
                }
            }

            // MARK: Ownership

            Section("Ownership") {
                Picker("Team", selection: $repository.team) {
                    Text("Unassigned").tag(Optional<Team>.none)
                    ForEach(teams) { team in
                        Text(team.name).tag(Optional(team))
                    }
                }
                .pickerStyle(.menu)
                Toggle("In Maintenance", isOn: $repository.isInMaintenance)
            }

            // MARK: Security Alerts

            let dependabotAlerts = (repository.dependabotAlertDetails ?? []).filter { $0.state == "open" }.sorted { $0.createdAt < $1.createdAt }
            let codeScanningAlerts = (repository.codeScanningAlertDetails ?? []).filter { $0.state == "open" }.sorted { $0.createdAt < $1.createdAt }
            let secretScanningAlerts = (repository.secretScanningAlertDetails ?? []).filter { $0.state == "open" }.sorted { $0.createdAt < $1.createdAt }

            Section("Security Alerts") {
                NavigationLink(destination: AllDependabotAlertsView(alerts: dependabotAlerts, repository: repository)) {
                    LabeledContent("Dependabot") {
                        Text("\(dependabotAlerts.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink(destination: AllCodeScanningAlertsView(alerts: codeScanningAlerts)) {
                    LabeledContent("Code Scanning") {
                        Text("\(codeScanningAlerts.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink(destination: AllSecretScanningAlertsView(alerts: secretScanningAlerts)) {
                    LabeledContent("Secret Scanning") {
                        Text("\(secretScanningAlerts.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: Info

            Section("Info") {
                LabeledContent("Owner", value: repository.owner)
                LabeledContent("Name", value: repository.name)
                LabeledContent("Language", value: repository.primaryLanguage ?? "None")
            }
        }
        .listStyle(.plain)
        .headerProminence(.increased)
        .navigationTitle(repository.displayName)
        .refreshable {
            print("[Refresh] Pull-to-refresh triggered for \(repository.owner)/\(repository.name)")
            let service = SecurityService(rest: RESTClient(tokenProvider: authService.tokenProvider))
            let openAlerts = await service.fetchDependabotAlerts(owner: repository.owner, repo: repository.name)
            if let openAlerts {
                print("[Refresh] fetchDependabotAlerts returned \(openAlerts.count) open alert(s)")
            } else {
                print("[Refresh] fetchDependabotAlerts returned nil (network or auth failure)")
            }
            await service.deltaApplyDependabotAlerts(
                openAlerts: openAlerts,
                owner: repository.owner,
                repo: repository.name,
                to: repository,
                in: modelContext
            )
            print("[Refresh] deltaApply complete")
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    /// Returns a human-readable label for how long a pull request has been open.
    private func daysOpenLabel(_ createdAt: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: createdAt, to: .now).day ?? 0
        return days == 1 ? "1 day open" : "\(days) days open"
    }
}

// MARK: - VelocityHeroRow

/// A hero-style row displaying merged PR count and year-over-year trend for a velocity period.
private struct VelocityHeroRow: View {

    // MARK: - Properties

    /// The velocity comparison data to render.
    let comparison: VelocityComparison

    // MARK: - Body

    /// The view's content.
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(comparison.current)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text("MERGED PRS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: trendIcon(comparison.trend))
                    .font(.system(size: 18, weight: .bold))
                    .symbolEffect(.bounce, value: comparison.trend)
                Text(badgeText(comparison))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(trendColor(comparison.trend))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(trendColor(comparison.trend).opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 26))
        .animation(.easeInOut(duration: 0.25), value: comparison.current)
    }

    // MARK: - Helpers

    /// Returns the SF Symbol name for the given trend direction.
    private func trendIcon(_ trend: VelocityComparison.Trend) -> String {
        switch trend {
        case .up:   return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }

    /// Returns the foreground color for the given trend direction.
    private func trendColor(_ trend: VelocityComparison.Trend) -> Color {
        switch trend {
        case .up:   return .green
        case .down: return .red
        case .flat: return .gray
        }
    }

    /// Returns a formatted percentage or delta string for the badge label.
    private func badgeText(_ c: VelocityComparison) -> String {
        if let pct = c.percentChange {
            return "\(Int(abs(pct.rounded())))%"
        }
        let sign = c.delta >= 0 ? "+" : ""
        return "\(sign)\(c.delta)"
    }
}
