import SwiftUI
import SwiftData

// MARK: - AddDisciplineView

struct AddDisciplineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

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

    // MARK: - Private

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        modelContext.insert(Discipline(name: trimmedName))
        dismiss()
    }
}
