import SwiftUI
import SwiftData

// MARK: - TeamDetailView

/// Displays the members and discipline breakdown for a team.
struct TeamDetailView: View {

    // MARK: - Properties

    /// The team whose detail data this view displays.
    let team: Team

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The authentication service used to construct clients for member management.
    @Environment(AuthenticationService.self) private var authService

    /// Tracks whether the add-member sheet is presented.
    @State private var isAddingMember = false

    // MARK: - Body

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
        }
        .listStyle(.plain)
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
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

    /// Members sorted alphabetically by name.
    private var sortedMembers: [Member] {
        team.members.sorted { $0.name < $1.name }
    }

    /// Deletes the member at the specified offset from the team.
    private func deleteMember(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedMembers[index])
        }
    }
}
