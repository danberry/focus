import SwiftUI
import SwiftData

// MARK: - TeamsView

struct TeamsView: View {
    @Query(sort: [SortDescriptor(\Team.name, comparator: .localizedStandard)]) private var teams: [Team]
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingTeam = false

    var body: some View {
        NavigationStack {
            Group {
                if teams.isEmpty {
                    ContentUnavailableView(
                        "No Teams",
                        systemImage: "person.2",
                        description: Text("Add a team to get started.")
                    )
                } else {
                    List {
                        ForEach(teams) { team in
                            NavigationLink(destination: TeamDetailView(team: team)) {
                                LabeledContent {
                                    Text("\(team.members.count)")
                                } label: {
                                    Text(team.name)
                                    Text(team.teamDescription)
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Teams")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingTeam = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingTeam) {
                AddTeamView()
            }
        }
    }

    // MARK: - Private

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(teams[index])
        }
    }
}

#Preview {
    TeamsView()
        .modelContainer(for: [Team.self, Member.self], inMemory: true)
}
