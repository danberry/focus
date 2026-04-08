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
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(VelocityPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                let record = repository.velocityMetrics.first { $0.periodType == selectedPeriod.rawValue }
                if let record {
                    VelocityHeroRow(comparison: record.comparison)
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
                }
            } header: {
                Text("Velocity")
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
                                    .lineLimit(1)
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

    // MARK: - Helpers

    private func daysOpenLabel(_ createdAt: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: createdAt, to: .now).day ?? 0
        return days == 1 ? "1 day open" : "\(days) days open"
    }
}

// MARK: - VelocityHeroRow

private struct VelocityHeroRow: View {
    let comparison: VelocityComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
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

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon(comparison.trend))
                            .font(.system(size: 14, weight: .bold))
                        Text(badgeText(comparison))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(trendColor(comparison.trend))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(trendColor(comparison.trend).opacity(0.12), in: Capsule())

                }
            }

            VelocityComparisonBar(
                current: comparison.current,
                prior: comparison.prior,
                trend: comparison.trend
            )
        }
        .padding(.vertical, 8)
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

// MARK: - VelocityComparisonBar

private struct VelocityComparisonBar: View {
    let current: Int
    let prior: Int
    let trend: VelocityComparison.Trend

    private var maxVal: Int { max(current, prior, 1) }
    private var currentRatio: Double { Double(current) / Double(maxVal) }
    private var priorRatio: Double { Double(prior) / Double(maxVal) }

    private var currentColor: Color {
        switch trend {
        case .up:   return .green
        case .down: return .red
        case .flat: return Color.primary
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            BarRow(label: "Now", value: current, ratio: currentRatio, color: currentColor)
            BarRow(label: "−1yr", value: prior, ratio: priorRatio, color: Color.primary.opacity(0.3))
        }
    }
}

private struct BarRow: View {
    let label: String
    let value: Int
    let ratio: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                    Capsule()
                        .fill(color)
                        .frame(width: max(6, proxy.size.width * ratio))
                }
            }
            .frame(height: 8)
            Text("\(value)")
                .font(.caption2.monospacedDigit())
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
                .contentTransition(.numericText())
        }
    }
}
