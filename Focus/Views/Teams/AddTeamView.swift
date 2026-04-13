import SwiftUI
import SwiftData

// MARK: - AddTeamView

/// A form for creating and saving a new local team.
struct AddTeamView: View {

    // MARK: - Properties

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The dismissal action, used to close the sheet after saving or cancellation.
    @Environment(\.dismiss) private var dismiss

    /// The team name entered by the user.
    @State private var name = ""

    /// The team description entered by the user.
    @State private var teamDescription = ""

    /// Whether the form inputs are non-empty and the team is ready to save.
    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !teamDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    /// The view's content.
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

    /// Trims whitespace from the inputs and inserts a new `Team` into the model context.
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = teamDescription.trimmingCharacters(in: .whitespaces)
        modelContext.insert(Team(name: trimmedName, teamDescription: trimmedDescription))
        dismiss()
    }
}
