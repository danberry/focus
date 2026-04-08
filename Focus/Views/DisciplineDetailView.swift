import SwiftUI
import SwiftData

// MARK: - DisciplineDetailView

struct DisciplineDetailView: View {
    @Bindable var discipline: Discipline
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingJobTitle = false

    private var sortedJobTitles: [JobTitle] {
        discipline.jobTitles.sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if discipline.jobTitles.isEmpty {
                ContentUnavailableView(
                    "No Job Titles",
                    systemImage: "person.text.rectangle",
                    description: Text("Add a job title to this discipline.")
                )
            } else {
                List {
                    ForEach(sortedJobTitles) { jobTitle in
                        NavigationLink(destination: JobTitleDetailView(jobTitle: jobTitle)) {
                            Text(jobTitle.name)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(discipline.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingJobTitle = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingJobTitle) {
            AddJobTitleView(discipline: discipline)
        }
    }

    // MARK: - Private

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedJobTitles[index])
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Discipline.self, JobTitle.self, configurations: config)
    let discipline = Discipline(name: "Engineering")
    container.mainContext.insert(discipline)
    discipline.jobTitles = [
        JobTitle(name: "Engineer I"),
        JobTitle(name: "Senior Engineer"),
        JobTitle(name: "Principal Engineer")
    ]
    return NavigationStack {
        DisciplineDetailView(discipline: discipline)
    }
    .modelContainer(container)
}
