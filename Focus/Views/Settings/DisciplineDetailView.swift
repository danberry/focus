import SwiftUI
import SwiftData

// MARK: - DisciplineDetailView

/// Displays and manages the job titles belonging to a discipline.
struct DisciplineDetailView: View {

    // MARK: - Properties

    /// The discipline whose job titles this view displays and edits.
    @Bindable var discipline: Discipline

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// Whether the add job title sheet is currently presented.
    @State private var isAddingJobTitle = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        List {
            Section {
                Toggle("Tracks GitHub Activity", isOn: $discipline.tracksGitHubActivity)
            } footer: {
                Text("When off, members in this discipline are excluded from inactivity alerts in the Briefing.")
            }

            if discipline.jobTitles.isEmpty {
                ContentUnavailableView(
                    "No Job Titles",
                    systemImage: "person.text.rectangle",
                    description: Text("Add a job title to this discipline.")
                )
            } else {
                Section("Job Titles") {
                    ForEach(sortedJobTitles) { jobTitle in
                        NavigationLink(destination: JobTitleDetailView(jobTitle: jobTitle)) {
                            Text(jobTitle.name)
                        }
                    }
                    .onDelete(perform: delete)
                }
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

    /// The discipline's job titles sorted alphabetically by name.
    private var sortedJobTitles: [JobTitle] {
        discipline.jobTitles.sorted { $0.name < $1.name }
    }

    /// Deletes job titles at the specified offsets from the sorted list.
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
