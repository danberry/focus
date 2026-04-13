import SwiftUI
import SwiftData

// MARK: - AddJobTitleView

/// A form for adding a new job title to a discipline.
struct AddJobTitleView: View {

    // MARK: - Properties

    /// The discipline to which the new job title will be added.
    let discipline: Discipline

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The dismiss action, used to close this sheet when the user cancels or saves.
    @Environment(\.dismiss) private var dismiss

    /// The name entered by the user for the new job title.
    @State private var name = ""

    // MARK: - Body

    /// The view's content.
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Senior Engineer", text: $name)
                } header: {
                    Text("Name")
                }
            }
            .navigationTitle("New Job Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        save()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Returns `true` when the name field contains at least one non-whitespace character.
    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Private

    /// Trims the entered name, creates a new ``JobTitle``, appends it to the discipline, and dismisses the sheet.
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let jobTitle = JobTitle(name: trimmedName)
        discipline.jobTitles.append(jobTitle)
        dismiss()
    }
}
