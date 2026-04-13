import SwiftUI
import SwiftData

// MARK: - JobTitleDetailView

/// Displays a form for editing a job title's name and provides a delete action.
struct JobTitleDetailView: View {

    // MARK: - Properties

    /// The job title being edited.
    @Bindable var jobTitle: JobTitle

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The dismiss action, used to pop the view after deletion.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Form {
            Section {
                TextField("e.g. Senior Engineer", text: $jobTitle.name)
            } header: {
                Text("Name")
            }

            Section {
                Button("Delete Job Title", role: .destructive) {
                    modelContext.delete(jobTitle)
                    dismiss()
                }
            }
        }
        .navigationTitle(jobTitle.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
