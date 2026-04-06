import SwiftUI
import SwiftData

// MARK: - AddJobTitleView

struct AddJobTitleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var level = ""

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !level.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. iOS Engineer", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    TextField("e.g. Senior", text: $level)
                } header: {
                    Text("Level")
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

    // MARK: - Private

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedLevel = level.trimmingCharacters(in: .whitespaces)
        modelContext.insert(JobTitle(name: trimmedName, level: trimmedLevel))
        dismiss()
    }
}
