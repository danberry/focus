import SwiftUI
import SwiftData

// MARK: - RepositoryDetailView

struct RepositoryDetailView: View {
    let repository: SavedRepository
    var body: some View {
        List {
            // MARK: Velocity

            Section("Velocity") {
                ForEach(VelocityPeriod.allCases, id: \.self) { period in
                    let record = repository.velocityMetrics.first { $0.periodType == period.rawValue }
                    HStack {
                        Text(period.rawValue)
                        Spacer()
                        if let record {
                            let c = record.comparison
                            HStack(spacing: 6) {
                                Text("\(c.current) PRs")
                                    .monospacedDigit()
                                Image(systemName: trendIcon(c.trend))
                                    .foregroundStyle(trendColor(c.trend))
                            }
                            .font(.subheadline)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: Open Pull Requests

            let sortedPRs = repository.openPullRequests.sorted { $0.createdAt < $1.createdAt }
            Section("Open Pull Requests (\(sortedPRs.count))") {
                if sortedPRs.isEmpty {
                    Text("No open pull requests")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPRs.prefix(10)) { pr in
                        NavigationLink(destination: PullRequestDetailView(pullRequest: pr)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pr.title)
                                Text(daysOpenLabel(pr.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if sortedPRs.count > 10 {
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
                        Label(
                            handle,
                            systemImage: handle.contains("/") ? "person.2" : "person"
                        )
                    }
                }
            }

            // MARK: Security Alerts

            Section("Dependabot Alerts") {
                if repository.dependabotAlertDetails.isEmpty {
                    Text("No open alerts")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(repository.dependabotAlertDetails.sorted { $0.createdAt < $1.createdAt }) { alert in
                        NavigationLink(destination: DependabotAlertDetailView(alert: alert, repository: repository)) {
                            LabeledContent(alert.packageName, value: alert.severity)
                        }
                    }
                }
            }

            Section("Code Scanning Alerts") {
                let sorted = repository.codeScanningAlertDetails.sorted { $0.createdAt < $1.createdAt }
                if sorted.isEmpty {
                    Text("No open alerts")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sorted) { alert in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.ruleName)
                            if let severity = alert.securitySeverityLevel {
                                Text(severity)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Secret Scanning Alerts") {
                let sorted = repository.secretScanningAlertDetails.sorted { $0.createdAt < $1.createdAt }
                if sorted.isEmpty {
                    Text("No open alerts")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sorted) { alert in
                        HStack {
                            Text(alert.secretTypeDisplayName)
                            Spacer()
                            Text(alert.validity)
                                .foregroundStyle(.secondary)
                        }
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

    // MARK: - Velocity Helpers

    private func trendIcon(_ trend: VelocityComparison.Trend) -> String {
        switch trend {
        case .up:   return "arrow.up"
        case .down: return "arrow.down"
        case .flat: return "minus"
        }
    }

    private func trendColor(_ trend: VelocityComparison.Trend) -> Color {
        switch trend {
        case .up:   return .green
        case .down: return .red
        case .flat: return .secondary
        }
    }

    private func daysOpenLabel(_ createdAt: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: createdAt, to: .now).day ?? 0
        return days == 1 ? "1 day open" : "\(days) days open"
    }

    private func trendLabel(_ c: VelocityComparison) -> String {
        let priorLabel = "\(c.prior) prior year"
        switch c.trend {
        case .flat:
            return "Same as \(priorLabel)"
        case .up, .down:
            let sign = c.delta > 0 ? "+" : ""
            if let pct = c.percentChange {
                return "\(sign)\(c.delta) vs \(priorLabel) (\(sign)\(Int(pct.rounded()))%)"
            } else {
                return "\(sign)\(c.delta) vs \(priorLabel)"
            }
        }
    }
}
