import SwiftUI

// MARK: - RepositoryDossierView

/// A scrollable "dossier" screen that summarizes a single repository across activity,
/// pull requests, people, security, and branches/releases.
///
/// Shares the `BriefingTheme` visual language — `BriefingColor`, `BriefingFont`, and
/// `.briefingCard()` — so it reads as part of the same editorial surface as the main
/// briefing. It accepts a fully assembled ``RepositoryDossier`` and is read-only.
struct RepositoryDossierView: View {

    // MARK: - Properties

    /// The dossier payload rendered by the view.
    let dossier: RepositoryDossier

    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Controls inline navigation bar title visibility — true once the scroll-view title is off screen.
    @State private var showNavTitle = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    metaStrip
                        .padding(.bottom, 6)
                    Text(dossier.displayName)
                        .font(.system(size: 38, weight: .regular, design: .serif))
                        .foregroundStyle(BriefingColor.ink)
                        .onScrollVisibilityChange(threshold: 1) { isVisible in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showNavTitle = !isVisible
                            }
                        }
                    if !dossier.description.isEmpty {
                        Text(dossier.description)
                            .font(BriefingFont.body)
                            .foregroundStyle(BriefingColor.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

                kpiStrip
                    .padding(.vertical, 12)

                Divider()
                    .foregroundStyle(BriefingColor.rule)

                // Activity section — custom layout to insert the meta strip between the header and the cards.
                VStack(alignment: .leading, spacing: 12) {
                    DossierSectionHeader(number: "01", title: "Activity")
                    if dossier.activityHeatmap.totalCommits > 0 {
                        activityMetaStrip
                    }
                    if sizeClass == .regular {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                            alignment: .leading,
                            spacing: 16
                        ) {
                            activityCards
                        }
                    } else {
                        VStack(spacing: 12) {
                            activityCards
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                Divider()
                    .foregroundStyle(BriefingColor.rule)

                section(number: "02", title: "Pull Requests") {
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            cardTitle("Open PRs")
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
                            cardTitle("Merged by Day")
                            if dossier.mergedByDay.isEmpty {
                                emptyText
                            } else {
                                BriefingSparkBarView(values: normalized(dossier.mergedByDay.map { Double($0.count) }))
                                weekdayLabels(dossier.mergedByDay)
                            }
                        }
                    }
                }

                Divider()
                    .foregroundStyle(BriefingColor.rule)

                section(number: "03", title: "People") {
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            cardTitle("Contributors (30d)")
                            if dossier.contributors.isEmpty {
                                emptyText
                            } else {
                                ForEach(dossier.contributors.prefix(6)) { contributor in
                                    contributorRow(contributor)
                                }
                            }
                        }
                    }
                }

                Divider()
                    .foregroundStyle(BriefingColor.rule)

                section(number: "04", title: "Health & Security") {
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            cardTitle("Security")
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(dossier.security.total)")
                                    .font(BriefingFont.kpiSupporting)
                                    .foregroundStyle(BriefingColor.ink)
                                Text("open alerts")
                                    .font(BriefingFont.meta)
                                    .foregroundStyle(BriefingColor.ink3)
                            }
                            LabeledContent("Critical", value: "\(dossier.security.critical)")
                                .font(BriefingFont.body)
                                .foregroundStyle(dossier.security.critical > 0 ? BriefingColor.red : BriefingColor.ink)
                            LabeledContent("High", value: "\(dossier.security.high)")
                                .font(BriefingFont.body)
                                .foregroundStyle(BriefingColor.ink)
                            LabeledContent("Moderate", value: "\(dossier.security.moderate)")
                                .font(BriefingFont.body)
                                .foregroundStyle(BriefingColor.ink)
                            LabeledContent("Low", value: "\(dossier.security.low)")
                                .font(BriefingFont.body)
                                .foregroundStyle(BriefingColor.ink)
                        }
                    }
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            cardTitle("Recent Alerts")
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
                    .foregroundStyle(BriefingColor.rule)

                section(number: "05", title: "Branches & Releases") {
                    DossierCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            cardTitle("Branches")
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
                            cardTitle("Releases")
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
        .background(BriefingColor.paper)
        .navigationTitle(showNavTitle ? dossier.displayName : "")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Meta Strip

    /// The single-line eyebrow above the repository name showing department, privacy, and last push.
    private var metaStrip: some View {
        let tokens: [String] = [
            dossier.department.map { $0.uppercased() },
            dossier.visibility,
            dossier.lastPushedAt.map { "LAST PUSH \(lastPushString(from: $0))" }
        ].compactMap { $0 }

        return Text(tokens.joined(separator: " · "))
            .font(BriefingFont.eyebrow)
            .foregroundStyle(BriefingColor.ink3)
            .textCase(.uppercase)
    }

    /// Returns a compact relative-time string for the given date, e.g. `"just now"`, `"14 min ago"`,
    /// `"3h ago"`, or `"5d ago"`.
    private func lastPushString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }

    // MARK: - Section Helpers

    /// Builds a section composed of an eyebrow header and a card grid.
    /// On regular-width (iPad/desktop) displays cards in two columns; on compact in one.
    @ViewBuilder
    private func section<Content: View>(number: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DossierSectionHeader(number: number, title: title)
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

    /// KPI strip: tiles filling the full width on regular-width displays; a 2×2 grid on compact (iPhone) displays.
    @ViewBuilder
    private var kpiStrip: some View {
        if sizeClass == .regular {
            HStack(spacing: 8) {
                kpiTiles(includeAll: true, showDividers: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                kpiTiles(includeAll: true, showDividers: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    /// The KPI tiles, with thin dividers injected between them on regular width.
    @ViewBuilder
    private func kpiTiles(includeAll: Bool, showDividers: Bool = true) -> some View {
        let tiles: [(label: String, value: String, delta: Int?, footnote: String?, isAlert: Bool)] = [
            ("Merged",             "\(dossier.kpi.mergedThisWeek)",     dossier.kpi.mergedThisWeekDelta, nil,                                                                       false),
            ("Open PRs",         "\(dossier.kpi.openPRs)",             nil,                            nil,                                                                       false),
("Security",         "\(dossier.kpi.securityAlerts)",      nil,                            dossier.kpi.criticalAlerts > 0 ? "\(dossier.kpi.criticalAlerts) critical" : nil, dossier.kpi.criticalAlerts > 0),
            ("Contributors 30d", "\(dossier.kpi.contributors30d)",     nil,                            nil,                                                                        false),
        ]
        ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
            if showDividers && index > 0 {
                Divider()
                    .frame(maxWidth: 1, maxHeight: .infinity)
                    .background(.gray400)
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

    // MARK: - Activity Section

    /// The meta strip shown between the Activity section header and the cards.
    private var activityMetaStrip: some View {
        let heatmap = dossier.activityHeatmap
        var parts: [String] = ["Last 26 weeks"]
        if heatmap.totalCommits > 0 {
            parts.append("\(heatmap.totalCommits.formatted(.number)) commits")
        }
        if let peak = heatmap.peakDate {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEE MMM d"
            parts.append("peak \(fmt.string(from: peak))")
        }
        return Text(parts.joined(separator: " · "))
            .font(BriefingFont.meta)
            .foregroundStyle(BriefingColor.ink3)
    }

    /// The heatmap card and velocity card shown inside the Activity section grid.
    @ViewBuilder
    private var activityCards: some View {
        DossierCardView {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle("Commit Heatmap")
                if dossier.activityHeatmap.cells.isEmpty {
                    emptyText
                } else {
                    DossierHeatmapView(
                        cells: dossier.activityHeatmap.cells,
                        startDate: dossier.activityHeatmap.startDate,
                        endDate: dossier.activityHeatmap.endDate,
                        peakDate: dossier.activityHeatmap.peakDate
                    )
                }
            }
        }
        .gridCellColumns(2)
        DossierVelocitySparkCardView(
            weeklyCommits: dossier.velocitySpark.weeklyCommits,
            percentageChange: dossier.velocitySpark.percentageChange,
            startDate: dossier.activityHeatmap.startDate
        )
    }

    // MARK: - Card Title

    /// An eyebrow-styled card section label.
    private func cardTitle(_ text: String, tone: BriefingTone = .neutral) -> some View {
        Text(text)
            .font(BriefingFont.eyebrow)
            .textCase(.uppercase)
            .foregroundStyle(tone == .red ? BriefingColor.red2 : BriefingColor.ink3)
    }

    // MARK: - Row Builders

    /// Renders a row inside the open-PR card.
    private func openPRRow(_ pr: RepositoryDossier.OpenPR) -> some View {
        HStack(spacing: 8) {
            Text("#\(pr.id, format: .number.grouping(.never))")
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
            Text(pr.title)
                .font(BriefingFont.body)
                .foregroundStyle(BriefingColor.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("@\(pr.authorLogin)")
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
                .lineLimit(1)
            Text(ageString(from: pr.createdAt))
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
        }
    }

    /// Renders a row inside the contributors card.
    private func contributorRow(_ contributor: RepositoryDossier.Contributor) -> some View {
        HStack(spacing: 8) {
            Text("@\(contributor.login)")
                .font(BriefingFont.body)
                .foregroundStyle(BriefingColor.ink)
                .lineLimit(1)
            if let role = contributor.role {
                Text(role)
                    .font(BriefingFont.meta)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(BriefingColor.paper3, in: Capsule())
                    .foregroundStyle(BriefingColor.ink2)
            }
            Spacer(minLength: 4)
            Text("\(contributor.mergedPRs30d)")
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
        }
    }

    /// Renders a row inside the alerts card.
    private func alertRow(_ alert: RepositoryDossier.AlertItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(severityColor(alert.severity))
                .frame(width: 8, height: 8)
            Text(alert.id)
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink)
            Text(alert.packageOrRule)
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(alert.ageInDays)d")
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
        }
    }

    /// Renders a row inside the branches card.
    private func branchRow(_ branch: RepositoryDossier.Branch) -> some View {
        HStack(spacing: 8) {
            Text(branch.name)
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink)
                .lineLimit(1)
                .truncationMode(.head)
            branchChip(branch.kind)
            Spacer(minLength: 4)
            if branch.aheadBy > 0 || branch.behindBy > 0 {
                Text("↑\(branch.aheadBy) ↓\(branch.behindBy)")
                    .font(BriefingFont.meta)
                    .foregroundStyle(BriefingColor.ink3)
            } else {
                Text("\(branch.ageInDays)d")
                    .font(BriefingFont.meta)
                    .foregroundStyle(BriefingColor.ink3)
            }
        }
    }

    /// A small chip describing a branch's classification.
    private func branchChip(_ kind: RepositoryDossier.Branch.Kind) -> some View {
        let label: String
        let color: Color
        let bg: Color
        switch kind {
        case .default:
            label = "default"
            color = BriefingColor.blue
            bg = BriefingColor.blueBg
        case .staging:
            label = "staging"
            color = BriefingColor.blue2
            bg = BriefingColor.blueBg
        case .behind:
            label = "behind"
            color = BriefingColor.red
            bg = BriefingColor.redBg
        case .stale:
            label = "stale"
            color = BriefingColor.red
            bg = BriefingColor.redBg
        }
        return Text(label)
            .font(BriefingFont.meta)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg, in: Capsule())
            .foregroundStyle(color)
    }

    /// Renders a row inside the releases card.
    private func releaseRow(_ release: RepositoryDossier.Release) -> some View {
        HStack(spacing: 8) {
            Text(release.tag)
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink)
            releaseChip(release.isMinor)
            Text(release.body)
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(release.ageInDays)d")
                .font(BriefingFont.meta)
                .foregroundStyle(BriefingColor.ink3)
        }
    }

    /// A small chip distinguishing minor releases from patch releases.
    private func releaseChip(_ isMinor: Bool) -> some View {
        let label: String
        let color: Color
        let bg: Color
        if isMinor {
            label = "minor"
            color = BriefingColor.blue
            bg = BriefingColor.blueBg
        } else {
            label = "patch"
            color = BriefingColor.ink3
            bg = BriefingColor.paper3
        }
        return Text(label)
            .font(BriefingFont.meta)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg, in: Capsule())
            .foregroundStyle(color)
    }

    /// Weekday axis labels rendered beneath a 7-day spark chart.
    private func weekdayLabels(_ days: [RepositoryDossier.DailyCount]) -> some View {
        HStack {
            ForEach(days) { day in
                Text(day.label)
                    .font(BriefingFont.meta)
                    .foregroundStyle(BriefingColor.ink3)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// A reusable empty-state placeholder shown inside cards with no data.
    private var emptyText: some View {
        Text("No data")
            .font(BriefingFont.body)
            .foregroundStyle(BriefingColor.ink3)
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
        case .critical: BriefingColor.red
        case .high: .orange
        case .moderate: .yellow
        case .low: BriefingColor.ink3
        }
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

/// The editorial-style eyebrow header rendered above each section inside ``RepositoryDossierView``.
///
/// Renders `§ {number}` as a small monospaced eyebrow followed by the section title in the
/// serif `sectionTitle` font, matching the typographic treatment used in ``SectionHeaderView``.
private struct DossierSectionHeader: View {

    /// The two-digit section number, e.g. `"01"`.
    let number: String

    /// The section title, e.g. `"Activity"`.
    let title: String

    /// The view's content.
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("§ \(number)")
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(BriefingColor.red)
            Text(title)
                .font(BriefingFont.sectionTitle)
                .foregroundStyle(BriefingColor.ink)
        }
    }
}

// MARK: - DossierCardView

/// A reusable card container using the `BriefingTheme` fill and border for the given tone.
struct DossierCardView<Content: View>: View {

    /// The semantic tone that drives fill and border colors.
    var tone: BriefingTone = .neutral

    /// The card's content.
    @ViewBuilder var content: Content

    /// The view's content.
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .briefingCard(tone: tone, flat: true)
    }
}

// MARK: - DossierKPITileView

/// A single compact KPI tile used in the dark horizontal KPI strip.
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

    /// When `true`, the tile renders the value in the red alert color.
    var isAlert: Bool = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BriefingFont.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(isAlert ? BriefingColor.red2 : BriefingColor.ink3)
                .lineLimit(1)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(BriefingFont.kpiSupporting)
                    .foregroundStyle(isAlert ? BriefingColor.red : BriefingColor.ink)
                if let delta {
                    deltaBadge(delta)
                }
            }
            if let footnote {
                Text(footnote)
                    .font(BriefingFont.meta)
                    .foregroundStyle(BriefingColor.ink3)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isAlert ? BriefingColor.redBg : BriefingColor.paper, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isAlert ? BriefingColor.red.opacity(0.25) : Color.primary.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Helpers

    /// A tiny badge showing the signed week-over-week delta.
    private func deltaBadge(_ value: Int) -> some View {
        let symbol = value > 0 ? "↑" : (value < 0 ? "↓" : "→")
        let color: Color = value > 0 ? BriefingColor.green : (value < 0 ? BriefingColor.red : .gray700)
        return Text(symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(color)
    }
}

// MARK: - DossierHeatmapView

/// A grid of small colored rectangles forming a 26-week × 7-day commit heatmap,
/// with optional start/end date labels along the bottom edge.
private struct DossierHeatmapView: View {

    /// Intensity values in row-major order, each in the range `0`–`4`.
    let cells: [Int]

    /// The date anchoring the left edge of the grid, displayed as a bottom-left label.
    var startDate: Date? = nil

    /// The date anchoring the right edge of the grid, displayed as a bottom-right label.
    var endDate: Date? = nil

    /// The calendar day with the highest commit count; its cell receives a green ring.
    var peakDate: Date? = nil

    /// The number of weekday rows in the grid.
    private let rows = 7

    /// The number of week columns in the grid.
    private let columns = 26

    /// The view's content.
    var body: some View {
        let peakIndex = peakCellIndex()
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let spacing: CGFloat = 2
                let cellWidth = min(12, max(2, (proxy.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)))
                VStack(spacing: spacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                let intensity = index < cells.count ? cells[index] : 0
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(BriefingColor.ink.opacity(opacity(for: intensity)))
                                    .overlay(
                                        peakIndex == index
                                            ? RoundedRectangle(cornerRadius: 2, style: .continuous)
                                                .strokeBorder(BriefingColor.green, lineWidth: 1.5)
                                            : nil
                                    )
                                    .frame(width: cellWidth, height: cellWidth)
                            }
                        }
                    }
                }
            }
            .frame(height: 7 * 12 + 6 * 2)

            if startDate != nil || endDate != nil {
                HStack {
                    if let start = startDate {
                        Text(shortDate(start))
                            .font(BriefingFont.meta)
                            .foregroundStyle(BriefingColor.ink3)
                    }
                    Spacer()
                    if let end = endDate {
                        Text(shortDate(end))
                            .font(BriefingFont.meta)
                            .foregroundStyle(BriefingColor.ink3)
                    }
                }
            }
        }
    }

    private func peakCellIndex() -> Int? {
        guard let start = startDate, let peak = peakDate else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let days = cal.dateComponents([.day], from: start, to: peak).day ?? -1
        guard days >= 0 else { return nil }
        let col = days / 7
        guard col < columns else { return nil }
        let row = cal.component(.weekday, from: peak) - 1
        return row * columns + col
    }

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }

    /// Maps an intensity bucket (`0`–`4`) to an opacity value.
    private func opacity(for intensity: Int) -> Double {
        switch intensity {
        case 1: 0.15
        case 2: 0.35
        case 3: 0.6
        case 4: 1.0
        default: 0.05
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RepositoryDossierView(dossier: .preview)
    }
}
