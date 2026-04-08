import SwiftUI
import SwiftData

// MARK: - RepositoryDetailView

struct RepositoryDetailView: View {
    let repository: SavedRepository
    @State private var selectedPeriod: VelocityPeriod = .thirtyDays

    var body: some View {
        List {
            // MARK: Velocity

            Section {
                let record = repository.velocityMetrics.first { $0.periodType == selectedPeriod.rawValue }
                if let record {
                    VelocityHeroRow(comparison: record.comparison, selectedPeriod: $selectedPeriod)
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
            }

            // MARK: Open Pull Requests

            let sortedPRs = repository.openPullRequests.sorted { $0.createdAt < $1.createdAt }
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
                let uniqueHandles = Array(Set(repository.codeowners.map(\.handle))).sorted()
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

            // MARK: Security Alerts

            Section("Dependabot Alerts") {
                let sortedDependabot = repository.dependabotAlertDetails.sorted { $0.createdAt < $1.createdAt }
                if sortedDependabot.isEmpty {
                    EmptyContentView("No Dependabot Alerts", systemImage: "shield.slash")
                } else {
                    ForEach(sortedDependabot.prefix(6)) { alert in
                        NavigationLink(destination: DependabotAlertDetailView(alert: alert, repository: repository)) {
                            LabeledContent(alert.packageName, value: alert.severity)
                        }
                    }
                    if sortedDependabot.count > 6 {
                        NavigationLink("Show all \(sortedDependabot.count) dependabot alerts") {
                            AllDependabotAlertsView(alerts: sortedDependabot, repository: repository)
                        }
                        .foregroundStyle(.tint)
                    }
                }
            }

            Section("Code Scanning Alerts") {
                let sortedCodeScanning = repository.codeScanningAlertDetails.sorted { $0.createdAt < $1.createdAt }
                if sortedCodeScanning.isEmpty {
                    EmptyContentView("No Code Scanning Alerts", systemImage: "shield.slash")
                } else {
                    ForEach(sortedCodeScanning.prefix(6)) { alert in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.ruleName)
                            if let severity = alert.securitySeverityLevel {
                                Text(severity)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if sortedCodeScanning.count > 6 {
                        NavigationLink("Show all \(sortedCodeScanning.count) code scanning alerts") {
                            AllCodeScanningAlertsView(alerts: sortedCodeScanning)
                        }
                        .foregroundStyle(.tint)
                    }
                }
            }

            Section("Secret Scanning Alerts") {
                let sortedSecretScanning = repository.secretScanningAlertDetails.sorted { $0.createdAt < $1.createdAt }
                if sortedSecretScanning.isEmpty {
                    EmptyContentView("No Secret Scanning Alerts", systemImage: "key.slash")
                } else {
                    ForEach(sortedSecretScanning.prefix(6)) { alert in
                        HStack {
                            Text(alert.secretTypeDisplayName)
                            Spacer()
                            Text(alert.validity)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if sortedSecretScanning.count > 6 {
                        NavigationLink("Show all \(sortedSecretScanning.count) secret scanning alerts") {
                            AllSecretScanningAlertsView(alerts: sortedSecretScanning)
                        }
                        .foregroundStyle(.tint)
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
        .navigationTitle(repository.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func daysOpenLabel(_ createdAt: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: createdAt, to: .now).day ?? 0
        return days == 1 ? "1 day open" : "\(days) days open"
    }
}

// MARK: - VelocityHeroRow

private struct VelocityHeroRow: View {
    let comparison: VelocityComparison
    @Binding var selectedPeriod: VelocityPeriod

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
                Text(badgeText(comparison))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(trendColor(comparison.trend))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(trendColor(comparison.trend).opacity(0.12), in: Capsule())

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
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 26))
        .animation(.easeInOut(duration: 0.25), value: comparison.current)
    }

    private func trendIcon(_ trend: VelocityComparison.Trend) -> String {
        switch trend {
        case .up:   return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }

    private func trendColor(_ trend: VelocityComparison.Trend) -> Color {
        switch trend {
        case .up:   return .green
        case .down: return .red
        case .flat: return .gray
        }
    }

    private func badgeText(_ c: VelocityComparison) -> String {
        if let pct = c.percentChange {
            return "\(Int(abs(pct.rounded())))%"
        }
        let sign = c.delta >= 0 ? "+" : ""
        return "\(sign)\(c.delta)"
    }
}
