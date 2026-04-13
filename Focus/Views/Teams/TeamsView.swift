import SwiftUI
import SwiftData

// MARK: - TeamsView

/// Displays the list of GitHub teams and provides navigation to team detail views.
struct TeamsView: View {

    // MARK: - Properties

    /// The SwiftData model context, injected from the root ``ModelContainer``.
    @Environment(\.modelContext) private var modelContext

    /// All teams fetched from the local store, sorted alphabetically by name.
    @Query(sort: [SortDescriptor(\Team.name, comparator: .localizedStandard)]) private var teams: [Team]

    /// Controls whether the add-team sheet is presented.
    @State private var isAddingTeam = false

    // MARK: - Body

    /// The view's content.
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

    // MARK: - Helpers

    /// Deletes the teams at the given offsets from the model context.
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
