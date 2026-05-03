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

    /// All departments fetched from the local store, sorted alphabetically by name.
    @Query(sort: \Department.name) private var departments: [Department]

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
                } else if isGrouped {
                    List {
                        ForEach(departmentsWithTeams) { dept in
                            Section(dept.name) {
                                ForEach((dept.teams ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { team in
                                    teamRow(for: team)
                                }
                            }
                        }
                        if !unassignedTeams.isEmpty {
                            Section("Unassigned") {
                                ForEach(unassignedTeams) { team in
                                    teamRow(for: team)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    List {
                        ForEach(teams) { team in
                            teamRow(for: team)
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

    /// Departments that have at least one assigned team.
    private var departmentsWithTeams: [Department] {
        departments.filter { !($0.teams ?? []).isEmpty }
    }

    /// Teams not assigned to any department.
    private var unassignedTeams: [Team] {
        teams.filter { $0.department == nil }
    }

    /// Whether at least one department has teams, triggering the grouped layout.
    private var isGrouped: Bool {
        !departmentsWithTeams.isEmpty
    }

    /// Builds the shared list row for a team, used by both grouped and flat layouts.
    ///
    /// - Parameter team: The team to render in the row.
    /// - Returns: A navigation link to ``TeamDetailView`` with the team's name, description, and member count.
    @ViewBuilder
    private func teamRow(for team: Team) -> some View {
        NavigationLink(destination: TeamDetailView(team: team)) {
            LabeledContent {
                Text("\(team.members?.count ?? 0)")
            } label: {
                Text(team.name)
                Text(team.teamDescription)
            }
        }
    }

    /// Deletes the teams at the given offsets from the model context.
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(teams[index])
        }
    }
}

#Preview {
    TeamsView()
        .modelContainer(for: [Team.self, Member.self, Department.self], inMemory: true)
}
