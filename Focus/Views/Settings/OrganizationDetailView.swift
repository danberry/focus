import SwiftUI
import SwiftData

// MARK: - OrganizationDetailView

/// A read-only hierarchy browser for a single ``SavedOrganization``.
///
/// Displays the organization's departments, directly-assigned teams (those with
/// no department), and the repositories owned by this organization via the
/// ``SavedRepository/organizationLogin`` soft foreign key.
struct OrganizationDetailView: View {

    // MARK: - Properties

    /// The organization whose hierarchy is being displayed.
    let organization: SavedOrganization

    /// The SwiftData model context, injected from the root ``ModelContainer``.
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    /// The view's content.
    var body: some View {
        List {
            // Dashboard link
            Section {
                NavigationLink("Dashboard") {
                    OrgDashboardView(organization: organization)
                }
            }

            // Departments section
            if !sortedDepartments.isEmpty {
                Section("Departments") {
                    ForEach(sortedDepartments) { dept in
                        NavigationLink(destination: DepartmentDetailView(department: dept)) {
                            Text(dept.name)
                                .badge(dept.teams?.count ?? 0)
                        }
                    }
                }
            }

            // Direct teams (org-assigned, no department)
            if !directTeams.isEmpty {
                Section("Teams") {
                    ForEach(directTeams) { team in
                        NavigationLink(destination: TeamDetailView(team: team)) {
                            LabeledContent {
                                Text("\(team.members?.count ?? 0)")
                            } label: {
                                Text(team.name)
                                Text(team.teamDescription)
                            }
                        }
                    }
                }
            }

            // Repos owned by this org (via organizationLogin soft FK)
            OrgRepositoriesSection(orgLogin: organization.login)
        }
        .listStyle(.plain)
        .navigationTitle(organization.name ?? organization.login)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    /// The organization's departments sorted alphabetically by name.
    private var sortedDepartments: [Department] {
        (organization.departments ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The teams directly assigned to this organization (without a department), sorted alphabetically by name.
    private var directTeams: [Team] {
        (organization.teams ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

// MARK: - OrgRepositoriesSection

/// A section listing the repositories whose ``SavedRepository/organizationLogin`` matches a given login.
///
/// Uses a dynamic ``Query`` filtered by the provided login string, so the
/// section updates live as repositories are added, removed, or reassigned.
private struct OrgRepositoriesSection: View {

    // MARK: - Properties

    /// The login handle of the organization whose repositories should be listed.
    let orgLogin: String

    /// The repositories whose `organizationLogin` matches ``orgLogin``.
    @Query private var repos: [SavedRepository]

    // MARK: - Init

    /// Creates a new repositories section scoped to the given organization login.
    ///
    /// - Parameter orgLogin: The login handle to filter repositories by.
    init(orgLogin: String) {
        self.orgLogin = orgLogin
        _repos = Query(
            filter: #Predicate<SavedRepository> { $0.organizationLogin == orgLogin },
            sort: [SortDescriptor(\SavedRepository.displayName, comparator: .localizedStandard)]
        )
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        if !repos.isEmpty {
            Section("Repositories") {
                ForEach(repos) { repo in
                    NavigationLink(destination: RepositoryDetailView(repository: repo)) {
                        SavedRepositoryRow(repository: repo)
                    }
                }
            }
        }
    }
}
