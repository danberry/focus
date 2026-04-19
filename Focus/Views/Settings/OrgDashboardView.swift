import SwiftUI
import SwiftData

// MARK: - OrgDashboardView

/// An executive-level dashboard for a single ``SavedOrganization``.
///
/// Presents a summary strip of high-level counts (departments, teams, repos,
/// open security alerts) and a list of per-department health cards summarizing
/// each department's teams, members, repositories, and open alert totals.
struct OrgDashboardView: View {

    // MARK: - Properties

    /// The organization whose dashboard is being displayed.
    let organization: SavedOrganization

    // MARK: - Body

    /// The view's content.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OrgSummaryStrip(organization: organization)
                if !sortedDepartments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Departments")
                            .font(.headline)
                            .padding(.horizontal)
                        ForEach(sortedDepartments) { dept in
                            DepartmentHealthCard(department: dept)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Departments",
                        systemImage: "building.2",
                        description: Text("Assign departments to this organization to see health cards.")
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Helpers

    /// The organization's departments sorted alphabetically by name.
    private var sortedDepartments: [Department] {
        organization.departments.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

// MARK: - OrgSummaryStrip

/// A horizontal strip of four stat tiles summarizing the organization's scope.
///
/// Surfaces department, team, and repository counts along with the rolled-up
/// total of open security alerts across all repositories owned by the org.
private struct OrgSummaryStrip: View {

    // MARK: - Properties

    /// The organization being summarized.
    let organization: SavedOrganization

    /// The repositories whose `organizationLogin` matches the organization's login.
    @Query private var repos: [SavedRepository]

    // MARK: - Init

    /// Creates a new summary strip scoped to the given organization.
    ///
    /// - Parameter organization: The organization whose stats should be displayed.
    init(organization: SavedOrganization) {
        self.organization = organization
        let login = organization.login
        _repos = Query(
            filter: #Predicate<SavedRepository> { $0.organizationLogin == login },
            sort: [SortDescriptor(\SavedRepository.displayName)]
        )
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        HStack(spacing: 12) {
            StatTile(value: organization.departments.count, label: "Departments")
            StatTile(value: organization.teams.count, label: "Teams")
            StatTile(value: repos.count, label: "Repos")
            StatTile(value: totalAlerts, label: "Alerts", isAlert: totalAlerts > 0)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    /// The sum of open security alerts across all repositories owned by the organization.
    private var totalAlerts: Int {
        repos.reduce(0) { $0 + $1.totalSecurityAlerts }
    }
}

// MARK: - DepartmentHealthCard

/// A card showing a single department's aggregated health metrics.
///
/// Aggregates counts of teams, members, and repositories under the department,
/// and surfaces the total count of open security alerts in red when nonzero.
private struct DepartmentHealthCard: View {

    // MARK: - Properties

    /// The department whose metrics are being displayed.
    let department: Department

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(department.name)
                .font(.headline)

            if let desc = department.departmentDescription {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 16) {
                Label("\(teamCount) teams", systemImage: "person.2")
                Label("\(memberCount) members", systemImage: "person.3")
                Label("\(repoCount) repos", systemImage: "doc.text")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if alertCount > 0 {
                Label("\(alertCount) open alerts", systemImage: "exclamationmark.shield")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    /// The number of teams in the department.
    private var teamCount: Int { department.teams.count }

    /// The total number of members across all teams in the department.
    private var memberCount: Int { department.teams.flatMap(\.members).count }

    /// The total number of repositories across all teams in the department.
    private var repoCount: Int { department.teams.flatMap(\.repositories).count }

    /// The total number of open security alerts across all repositories owned by
    /// teams in the department.
    private var alertCount: Int {
        department.teams.flatMap(\.repositories).reduce(0) { $0 + $1.totalSecurityAlerts }
    }
}

// MARK: - StatTile

/// A single labeled numeric stat tile for the summary strip.
///
/// Displays a numeric value above a caption, with optional red tint when
/// ``isAlert`` is `true` to draw attention to nonzero alert counts.
private struct StatTile: View {

    // MARK: - Properties

    /// The numeric value shown at the top of the tile.
    let value: Int

    /// The caption shown below the value.
    let label: String

    /// Whether the value should be styled as an alert (red foreground). Defaults to `false`.
    var isAlert: Bool = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(isAlert ? .red : .primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        OrgDashboardView(organization: {
            let org = SavedOrganization(githubId: "1", login: "acme", name: "Acme Corp")
            return org
        }())
    }
    .modelContainer(for: [SavedOrganization.self, Department.self, Team.self, SavedRepository.self, Member.self], inMemory: true)
}
