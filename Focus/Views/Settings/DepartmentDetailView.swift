import SwiftUI
import SwiftData

// MARK: - DepartmentDetailView

/// Displays and edits a department's name, description, organization, and teams.
struct DepartmentDetailView: View {

    // MARK: - Properties

    /// The department being edited.
    @Bindable var department: Department

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The dismiss action, used to pop the view after deletion.
    @Environment(\.dismiss) private var dismiss

    /// All saved organizations, used to populate the organization picker.
    @Query(sort: \SavedOrganization.login) private var organizations: [SavedOrganization]

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Form {
            Section {
                TextField("Department name", text: $department.name)
            } header: {
                Text("Name")
            }

            Section {
                TextField(
                    "Optional description",
                    text: Binding(
                        get: { department.departmentDescription ?? "" },
                        set: { department.departmentDescription = $0.isEmpty ? nil : $0 }
                    )
                )
                .lineLimit(3, reservesSpace: false)
            } header: {
                Text("Description")
            }

            Section {
                Picker("Organization", selection: $department.organization) {
                    Text("None").tag(Optional<SavedOrganization>.none)
                    ForEach(organizations) { org in
                        Text(org.name ?? org.login).tag(Optional(org))
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Organization")
            }

            Section {
                if sortedTeams.isEmpty {
                    Text("No teams assigned")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedTeams) { team in
                        Text(team.name)
                    }
                    .onDelete(perform: removeTeam)
                }
            } header: {
                Text("Teams")
            }

            Section {
                Button("Delete Department", role: .destructive) {
                    modelContext.delete(department)
                    dismiss()
                }
            }
        }
        .navigationTitle(department.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    /// The department's teams sorted alphabetically by name.
    private var sortedTeams: [Team] {
        (department.teams ?? []).sorted { $0.name < $1.name }
    }

    /// Removes the teams at the specified offsets from this department by nullifying their back-reference.
    private func removeTeam(at offsets: IndexSet) {
        let teams = sortedTeams
        for index in offsets {
            teams[index].department = nil
        }
    }
}
