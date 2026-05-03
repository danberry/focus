import SwiftUI
import SwiftData

// MARK: - DepartmentsView

/// Displays all departments and allows adding or removing them.
struct DepartmentsView: View {

    // MARK: - Properties

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// All departments, sorted alphabetically by name.
    @Query(sort: \Department.name) private var departments: [Department]

    /// Controls whether the add-department sheet is presented.
    @State private var isAddingDepartment = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Group {
            if departments.isEmpty {
                ContentUnavailableView(
                    "No Departments",
                    systemImage: "building.2",
                    description: Text("Add a department to get started.")
                )
            } else {
                List {
                    ForEach(departments) { department in
                        NavigationLink(destination: DepartmentDetailView(department: department)) {
                            Text(department.name)
                                .badge(department.teams?.count ?? 0)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Departments")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingDepartment = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingDepartment) {
            AddDepartmentView()
        }
    }

    // MARK: - Helpers

    /// Deletes the departments at the given index set from the model context.
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(departments[index])
        }
    }
}

#Preview {
    NavigationStack {
        DepartmentsView()
    }
    .modelContainer(for: [Department.self, Team.self], inMemory: true)
}
