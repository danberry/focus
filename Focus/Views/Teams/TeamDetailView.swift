import SwiftUI
import SwiftData

// MARK: - TeamDetailView

/// Displays the members and discipline breakdown for a team.
struct TeamDetailView: View {

    // MARK: - Properties

    /// The team whose detail data this view displays.
    @Bindable var team: Team

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The authentication service used to construct clients for member management.
    @Environment(AuthenticationService.self) private var authService

    /// All saved organizations, used to populate the organization picker.
    @Query(sort: \SavedOrganization.login) private var organizations: [SavedOrganization]

    /// All departments, used to populate the department picker.
    @Query(sort: \Department.name) private var departments: [Department]

    /// Tracks whether the add-member sheet is presented.
    @State private var isAddingMember = false

    // MARK: - Body

    /// The contribution service used to refresh member data on pull-to-refresh.
    private var contributionService: ContributionService {
        ContributionService(graphQL: GraphQLClient(tokenProvider: authService.tokenProvider))
    }

    /// The view's content.
    var body: some View {
        List {
            if !sortedMembers.isEmpty {
                Section {
                    JobTitleDonutChartView(members: sortedMembers)
                        .listRowSeparator(.hidden)
                }
            }

            if sortedMembers.isEmpty {
                EmptyContentView("No Members", systemImage: "person.2")
            } else {
                Section("Members") {
                    ForEach(sortedMembers) { member in
                        NavigationLink {
                            MemberDetailView(member: member)
                        } label: {
                            HStack(spacing: 10) {
                                MemberAvatarView(member: member)
                                VStack(alignment: .leading) {
                                    Text(member.name)
                                    if let title = member.jobTitle {
                                        Text(title.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .badge(member.totalContributions)
                        }
                    }
                    .onDelete(perform: deleteMember)
                }
            }

            Section("Assignment") {
                Picker("Organization", selection: $team.organization) {
                    Text("None").tag(Optional<SavedOrganization>.none)
                    ForEach(organizations) { org in
                        Text(org.name ?? org.login).tag(Optional(org))
                    }
                }
                .pickerStyle(.menu)

                let availableDepartments: [Department] = team.organization == nil
                    ? departments
                    : departments.filter { $0.organization?.login == team.organization?.login }

                Picker("Department", selection: $team.department) {
                    Text("None").tag(Optional<Department>.none)
                    ForEach(availableDepartments) { dept in
                        Text(dept.name).tag(Optional(dept))
                    }
                }
                .pickerStyle(.menu)
                .disabled(departments.isEmpty)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshMembers()
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: team.organization) { _, newOrg in
            if let dept = team.department, let newOrg {
                if dept.organization?.login != newOrg.login {
                    team.department = nil
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingMember = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingMember) {
            AddMemberView(
                team: team,
                restClient: RESTClient(tokenProvider: authService.tokenProvider),
                contributionService: ContributionService(
                    graphQL: GraphQLClient(tokenProvider: authService.tokenProvider)
                )
            )
        }
    }

    // MARK: - Helpers

    /// Syncs contribution data for all team members that have a GitHub login.
    @MainActor
    private func refreshMembers() async {
        let membersWithLogin = sortedMembers.filter { $0.githubLogin != nil }
        for member in membersWithLogin {
            guard let login = member.githubLogin else { continue }
            await contributionService.syncContributions(login: login, member: member, in: modelContext)
        }
        if !membersWithLogin.isEmpty {
            team.membersLastUpdated = Date()
        }
    }

    /// Members sorted alphabetically by name.
    private var sortedMembers: [Member] {
        (team.members ?? []).sorted { $0.name < $1.name }
    }

    /// Deletes the member at the specified offset from the team.
    private func deleteMember(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedMembers[index])
        }
        team.membersLastUpdated = Date()
    }
}
