import SwiftUI
import SwiftData

// MARK: - AddDisciplineView

/// A form for creating a new discipline.
struct AddDisciplineView: View {

    // MARK: - Properties

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The dismiss action for closing this sheet.
    @Environment(\.dismiss) private var dismiss

    /// The name entered by the user for the new discipline.
    @State private var name = ""

    /// Whether the form has enough valid input to submit.
    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Engineering", text: $name)
                } header: {
                    Text("Name")
                }
            }
            .navigationTitle("New Discipline")
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

    /// Trims the name, inserts a new `Discipline`, and dismisses the sheet.
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        modelContext.insert(Discipline(name: trimmedName))
        dismiss()
    }
}
