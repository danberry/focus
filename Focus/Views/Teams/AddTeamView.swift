import SwiftUI
import SwiftData

// MARK: - AddTeamView

struct AddTeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var teamDescription = ""

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !teamDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. iOS Platform", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    TextField("e.g. Owns the iOS app", text: $teamDescription)
                } header: {
                    Text("Description")
                }
            }
            .navigationTitle("New Team")
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
        let trimmedDescription = teamDescription.trimmingCharacters(in: .whitespaces)
        modelContext.insert(Team(name: trimmedName, teamDescription: trimmedDescription))
        dismiss()
    }
}
