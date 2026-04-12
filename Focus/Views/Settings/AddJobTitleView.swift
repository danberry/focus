import SwiftUI
import SwiftData

// MARK: - AddJobTitleView

struct AddJobTitleView: View {
    let discipline: Discipline

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

    // MARK: - Private

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let jobTitle = JobTitle(name: trimmedName)
        discipline.jobTitles.append(jobTitle)
        dismiss()
    }
}
