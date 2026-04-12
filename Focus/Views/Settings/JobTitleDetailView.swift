import SwiftUI
import SwiftData

// MARK: - JobTitleDetailView

struct JobTitleDetailView: View {
    @Bindable var jobTitle: JobTitle
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
