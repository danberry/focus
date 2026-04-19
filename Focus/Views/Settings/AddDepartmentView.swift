import SwiftUI
import SwiftData

// MARK: - AddDepartmentView

/// A form for creating a new department.
struct AddDepartmentView: View {

    // MARK: - Properties

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The dismiss action for closing this sheet.
    @Environment(\.dismiss) private var dismiss

    /// The name entered by the user for the new department.
    @State private var name = ""

    /// The optional description entered by the user for the new department.
    @State private var departmentDescription = ""

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
                    TextField("e.g. Platform Engineering", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    TextField("e.g. Owns shared infrastructure", text: $departmentDescription)
                } header: {
                    Text("Description")
                }
            }
            .navigationTitle("New Department")
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

    /// Trims the inputs, inserts a new `Department`, and dismisses the sheet.
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = departmentDescription.trimmingCharacters(in: .whitespaces)
        let dept = Department(
            name: trimmedName,
            departmentDescription: trimmedDescription.isEmpty ? nil : trimmedDescription
        )
        modelContext.insert(dept)
        dismiss()
    }
}
