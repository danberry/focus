import SwiftUI

// MARK: - RepositoryDossierView

/// A scrollable "dossier" screen that summarizes a single repository across activity,
/// pull requests, people, security, and branches/releases.
///
/// This view is read-only and accepts a fully assembled ``RepositoryDossier``. It is a
/// distinct entry point from `RepositoryDetailView` and currently renders stubbed data.
struct RepositoryDossierView: View {

    // MARK: - Properties

    /// The dossier payload rendered by the view.
    let dossier: RepositoryDossier

    @Environment(\.horizontalSizeClass) private var sizeClass

    // MARK: - Body

    /// The view's content.
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                kpiStrip
                    .padding(.vertical, 12)

                Divider()

                section(title: "01 · Activity") {
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Commit Heatmap")
                                .font(.subheadline.weight(.semibold))
                            DossierHeatmapView(cells: dossier.activityHeatmap.cells)
                        }
                    }
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Velocity (16w)")
                                .font(.subheadline.weight(.semibold))
                            if dossier.velocitySpark.weeklyMerged.isEmpty {
                                emptyText
                            } else {
                                BriefingSparkBarView(values: normalized(dossier.velocitySpark.weeklyMerged.map(Double.init)))
                            }
                        }
                    }
                }

                Divider()

                section(title: "02 · Pull Requests") {
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Open PRs")
                                .font(.subheadline.weight(.semibold))
                            if dossier.openPRs.isEmpty {
                                emptyText
                            } else {
                                ForEach(dossier.openPRs.prefix(5)) { pr in
                                    openPRRow(pr)
                                }
                            }
                        }
                    }
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Merged by Day")
                                .font(.subheadline.weight(.semibold))
                            if dossier.mergedByDay.isEmpty {
                                emptyText
                            } else {
                                BriefingSparkBarView(values: normalized(dossier.mergedByDay.map { Double($0.count) }))
                                weekdayLabels(dossier.mergedByDay)
                            }
                        }
                    }
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CI Runs by Day")
                                .font(.subheadline.weight(.semibold))
                            if dossier.ciRunsByDay.isEmpty {
                                emptyText
                            } else {
                                BriefingSparkBarView(values: normalized(dossier.ciRunsByDay.map { Double($0.count) }))
                                weekdayLabels(dossier.ciRunsByDay)
                            }
                        }
                    }
                }

                Divider()

                section(title: "03 · People") {
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contributors (30d)")
                                .font(.subheadline.weight(.semibold))
                            if dossier.contributors.isEmpty {
                                emptyText
                            } else {
                                ForEach(dossier.contributors.prefix(6)) { contributor in
                                    contributorRow(contributor)
                                }
                            }
                        }
                    }
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hot Files (30d)")
                                .font(.subheadline.weight(.semibold))
                            if dossier.hotFiles.isEmpty {
                                emptyText
                            } else {
                                ForEach(dossier.hotFiles.prefix(6)) { file in
                                    hotFileRow(file)
                                }
                            }
                        }
                    }
                }

                Divider()

                section(title: "04 · Health & Security") {
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Security")
                                .font(.subheadline.weight(.semibold))
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(dossier.security.total)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Text("open alerts")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            LabeledContent("Critical", value: "\(dossier.security.critical)")
                                .foregroundStyle(dossier.security.critical > 0 ? Color.red : Color.primary)
                            LabeledContent("High", value: "\(dossier.security.high)")
                            LabeledContent("Moderate", value: "\(dossier.security.moderate)")
                            LabeledContent("Low", value: "\(dossier.security.low)")
                        }
                    }
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Alerts")
                                .font(.subheadline.weight(.semibold))
                            if dossier.alertItems.isEmpty {
                                emptyText
                            } else {
                                ForEach(dossier.alertItems.prefix(5)) { alert in
                                    alertRow(alert)
                                }
                            }
                        }
                    }
                }

                Divider()

                section(title: "05 · Branches & Releases") {
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Branches")
                                .font(.subheadline.weight(.semibold))
                            if dossier.branches.isEmpty {
                                emptyText
                            } else {
                                ForEach(dossier.branches.prefix(6)) { branch in
                                    branchRow(branch)
                                }
                            }
                        }
                    }
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Releases")
                                .font(.subheadline.weight(.semibold))
                            if dossier.releases.isEmpty {
                                emptyText
                            } else {
                                ForEach(dossier.releases.prefix(5)) { release in
                                    releaseRow(release)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(dossier.name)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Section Helpers

    /// Builds a section composed of an eyebrow header and a card grid.
    /// On regular-width (iPad/desktop) displays cards in two columns; on compact in one.
    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DossierSectionHeader(title: title)
            if sizeClass == .regular {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                    alignment: .leading,
                    spacing: 16
                ) {
                    content()
                }
            } else {
                VStack(spacing: 12) {
                    content()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: - KPI Strip

    /// KPI strip: six tiles with `|` dividers filling the full width on regular-width displays;
    /// a horizontally scrolling row of fixed-width tiles on compact displays.
    @ViewBuilder
    private var kpiStrip: some View {
        if sizeClass == .regular {
            HStack(spacing: 0) {
                kpiTiles(includeAll: true)
            }
            .padding(.horizontal, 16)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    kpiTiles(includeAll: false)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// The KPI tiles, with thin `Divider()` separators injected between them on regular width.
    @ViewBuilder
    private func kpiTiles(includeAll: Bool) -> some View {
        let tiles: [(label: String, value: String, delta: Int?, footnote: String?, isAlert: Bool)] = [
            ("Merged · Week",     "\(dossier.kpi.mergedThisWeek)",                        dossier.kpi.mergedThisWeekDelta, nil,                                                                       false),
            ("Open PRs",         "\(dossier.kpi.openPRs)",                               nil,                            dossier.kpi.stalePRs > 0 ? "\(dossier.kpi.stalePRs) stale" : nil,         false),
            ("Open Issues",      "\(dossier.kpi.openIssues)",                            nil,                            "\(dossier.kpi.closedIssues7d) closed 7d",                                  false),
            ("Security",         "\(dossier.kpi.securityAlerts)",                        nil,                            dossier.kpi.criticalAlerts > 0 ? "\(dossier.kpi.criticalAlerts) critical" : nil, dossier.kpi.criticalAlerts > 0),
            ("CI Pass",          "\(Int(dossier.kpi.ciPassPct.rounded()))%",             nil,                            "\(dossier.kpi.ciRuns7d) runs 7d",                                          false),
            ("Contributors 30d", "\(dossier.kpi.contributors30d)",                       nil,                            nil,                                                                        false),
        ]
        ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
            if includeAll && index > 0 {
                Divider()
                    .frame(height: 44)
            }
            DossierKPITileView(
                label: tile.label,
                value: tile.value,
                delta: tile.delta,
                footnote: tile.footnote,
                isAlert: tile.isAlert
            )
            .frame(maxWidth: includeAll ? .infinity : nil)
        }
    }

    // MARK: - Row Builders

    /// Renders a row inside the open-PR card.
    private func openPRRow(_ pr: RepositoryDossier.OpenPR) -> some View {
        HStack(spacing: 8) {
            Text("#\(pr.id)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text(pr.title)
                .font(.subheadline)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("@\(pr.authorLogin)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(ageString(from: pr.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
            ciChip(pr.ciStatus)
        }
    }

    /// A small colored chip representing CI status.
    private func ciChip(_ status: RepositoryDossier.OpenPR.CIStatus) -> some View {
        let symbol: String
        let color: Color
        switch status {
        case .passing:
            symbol = "checkmark.circle.fill"
            color = .green
        case .failing:
            symbol = "xmark.octagon.fill"
            color = .red
        case .none:
            symbol = "circle.dashed"
            color = .secondary
        }
        return Image(systemName: symbol)
            .font(.caption)
            .foregroundStyle(color)
    }

    /// Renders a row inside the contributors card.
    private func contributorRow(_ contributor: RepositoryDossier.Contributor) -> some View {
        HStack(spacing: 8) {
            Text("@\(contributor.login)")
                .font(.subheadline)
                .lineLimit(1)
            if let role = contributor.role {
                Text(role)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            Spacer(minLength: 4)
            Text("\(contributor.mergedPRs30d)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    /// Renders a row inside the hot-files card.
    private func hotFileRow(_ file: RepositoryDossier.HotFile) -> some View {
        HStack(spacing: 8) {
            Text(fileName(from: file.path))
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer(minLength: 4)
            Text("\(file.churns30d)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    /// Renders a row inside the alerts card.
    private func alertRow(_ alert: RepositoryDossier.AlertItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(severityColor(alert.severity))
                .frame(width: 8, height: 8)
            Text(alert.id)
                .font(.caption.monospaced())
            Text(alert.packageOrRule)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(alert.ageInDays)d")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Renders a row inside the branches card.
    private func branchRow(_ branch: RepositoryDossier.Branch) -> some View {
        HStack(spacing: 8) {
            Text(branch.name)
                .font(.subheadline.monospaced())
                .lineLimit(1)
                .truncationMode(.head)
            branchChip(branch.kind)
            Spacer(minLength: 4)
            Text("↑\(branch.aheadBy) ↓\(branch.behindBy)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    /// A small chip describing a branch's classification.
    private func branchChip(_ kind: RepositoryDossier.Branch.Kind) -> some View {
        let label: String
        let color: Color
        switch kind {
        case .default:
            label = "default"
            color = .blue
        case .staging:
            label = "staging"
            color = .purple
        case .behind:
            label = "behind"
            color = .orange
        case .stale:
            label = "stale"
            color = .red
        }
        return Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    /// Renders a row inside the releases card.
    private func releaseRow(_ release: RepositoryDossier.Release) -> some View {
        HStack(spacing: 8) {
            Text(release.tag)
                .font(.subheadline.monospaced())
            Text(release.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(release.ageInDays)d")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Weekday axis labels rendered beneath a 7-day spark chart.
    private func weekdayLabels(_ days: [RepositoryDossier.DailyCount]) -> some View {
        HStack {
            ForEach(days) { day in
                Text(day.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// A reusable empty-state placeholder shown inside cards with no data.
    private var emptyText: some View {
        Text("No data")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    // MARK: - Pure Helpers

    /// Returns a `0.0`–`1.0` normalization of the given values relative to their max.
    private func normalized(_ values: [Double]) -> [Double] {
        guard let peak = values.max(), peak > 0 else { return values.map { _ in 0 } }
        return values.map { $0 / peak }
    }

    /// Maps an alert severity to its display color.
    private func severityColor(_ severity: RepositoryDossier.AlertItem.Severity) -> Color {
        switch severity {
        case .critical: .red
        case .high: .orange
        case .moderate: .yellow
        case .low: .secondary
        }
    }

    /// Extracts the trailing path component (file name) from a repository-relative path.
    private func fileName(from path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    /// Returns a compact "Nd" / "Nh" age label for the given timestamp.
    private func ageString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        if hours < 24 { return "\(max(1, hours))h" }
        return "\(hours / 24)d"
    }
}

// MARK: - DossierSectionHeader

/// A bold eyebrow label used above each grouping of cards inside ``RepositoryDossierView``.
private struct DossierSectionHeader: View {

    /// The header text.
    let title: String

    /// The view's content.
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

// MARK: - DossierCardView

/// A reusable card container with secondary background and rounded corners.
private struct DossierCardView<Content: View>: View {

    /// The card's content.
    @ViewBuilder var content: Content

    /// The view's content.
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}

// MARK: - DossierKPITileView

/// A single compact KPI tile used in the horizontal KPI strip.
private struct DossierKPITileView: View {

    // MARK: - Properties

    /// The tile's label.
    let label: String

    /// The primary numeric value.
    let value: String

    /// An optional week-over-week delta.
    var delta: Int? = nil

    /// An optional secondary footnote (e.g. `"3 critical"`).
    var footnote: String? = nil

    /// When `true`, the tile renders the value in a warning color.
    var isAlert: Bool = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isAlert ? Color.red : Color.primary)
                if let delta {
                    deltaBadge(delta)
                }
            }
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 110, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Helpers

    /// A tiny badge showing the signed week-over-week delta.
    private func deltaBadge(_ value: Int) -> some View {
        let symbol = value > 0 ? "▲" : (value < 0 ? "▼" : "•")
        let color: Color = value > 0 ? .green : (value < 0 ? .red : .secondary)
        return Text("\(symbol)\(abs(value))")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(color)
    }
}

// MARK: - DossierHeatmapView

/// A grid of small colored rectangles forming a 26-week × 7-day commit heatmap.
private struct DossierHeatmapView: View {

    /// Intensity values in row-major order, each in the range `0`–`4`.
    let cells: [Int]

    /// The number of weekday rows in the grid.
    private let rows = 7

    /// The number of week columns in the grid.
    private let columns = 26

    /// The view's content.
    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 2
            let cellWidth = max(2, (proxy.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            let intensity = index < cells.count ? cells[index] : 0
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color.accentColor.opacity(opacity(for: intensity)))
                                .frame(width: cellWidth, height: cellWidth)
                        }
                    }
                }
            }
        }
        .frame(height: 7 * 12 + 6 * 2)
    }

    /// Maps an intensity bucket (`0`–`4`) to an opacity value.
    private func opacity(for intensity: Int) -> Double {
        switch intensity {
        case 1: 0.15
        case 2: 0.35
        case 3: 0.6
        case 4: 1.0
        default: 0.0
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RepositoryDossierView(dossier: .preview)
    }
}
