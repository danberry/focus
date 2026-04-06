import SwiftUI
import SwiftData

// MARK: - JobTitlesView

struct JobTitlesView: View {
    @Query(sort: \JobTitle.name) private var jobTitles: [JobTitle]
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingJobTitle = false

    var body: some View {
        NavigationStack {
            Group {
                if jobTitles.isEmpty {
                    ContentUnavailableView(
                        "No Job Titles",
                        systemImage: "briefcase",
                        description: Text("Add a job title to get started.")
                    )
                } else {
                    List {
                        ForEach(jobTitles) { jobTitle in
                            NavigationLink(destination: JobTitleDetailView(jobTitle: jobTitle)) {
                                VStack(alignment: .leading) {
                                    Text(jobTitle.name)
                                    Text(jobTitle.level)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Job Titles")
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
                AddJobTitleView()
            }
        }
    }

    // MARK: - Private

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(jobTitles[index])
        }
    }
}

#Preview {
    JobTitlesView()
        .modelContainer(for: [JobTitle.self], inMemory: true)
}
