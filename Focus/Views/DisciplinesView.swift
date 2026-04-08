import SwiftUI
import SwiftData

// MARK: - DisciplinesView

struct DisciplinesView: View {
    @Query(sort: \Discipline.name) private var disciplines: [Discipline]
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingDiscipline = false

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
                                .badge(discipline.jobTitles.count)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
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

    // MARK: - Private

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
