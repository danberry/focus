import SwiftUI
import SwiftData

// MARK: - TeamDetailView

struct TeamDetailView: View {
    let team: Team

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationService.self) private var authService

    @State private var isAddingMember = false

    private var sortedMembers: [Member] {
        team.members.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            Section {
                Text(team.teamDescription)
                    .foregroundStyle(.secondary)
            }

            Section("Members") {
                if sortedMembers.isEmpty {
                    Text("No members yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedMembers) { member in
                        HStack(spacing: 10) {
                            MemberAvatarView(member: member)
                            VStack(alignment: .leading) {
                                Text(member.name)
                                if member.githubId != nil {
                                    Text("GitHub account linked")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .badge(member.totalContributions)
                    }
                    .onDelete(perform: deleteMember)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(team.name)
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

    // MARK: - Private

    private func deleteMember(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedMembers[index])
        }
    }
}
