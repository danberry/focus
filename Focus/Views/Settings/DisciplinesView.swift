import SwiftUI
import SwiftData

// MARK: - DisciplinesView

/// Displays all disciplines and allows adding or removing them.
struct DisciplinesView: View {

    // MARK: - Properties

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// All disciplines, sorted alphabetically by name.
    @Query(sort: \Discipline.name) private var disciplines: [Discipline]

    /// Controls whether the add-discipline sheet is presented.
    @State private var isAddingDiscipline = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Group {
            if disciplines.isEmpty {
                ContentUnavailableView(
                    "No Disciplines",
                    systemImage: "briefcase",
                    description: Text("Add a discipline to get started.")
                )
            } else {
                List {
                    ForEach(disciplines) { discipline in
                        NavigationLink(destination: DisciplineDetailView(discipline: discipline)) {
                            Text(discipline.name)
                                .badge(discipline.jobTitles?.count ?? 0)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Disciplines")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingDiscipline = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingDiscipline) {
            AddDisciplineView()
        }
    }

    // MARK: - Helpers

    /// Deletes the disciplines at the given index set from the model context.
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(disciplines[index])
        }
    }
}

#Preview {
    NavigationStack {
        DisciplinesView()
    }
    .modelContainer(for: [Discipline.self, JobTitle.self], inMemory: true)
}
