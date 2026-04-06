import SwiftUI

// MARK: - AssignCodeOwnerView

struct AssignCodeOwnerView: View {
    let alert: DependabotAlert
    let repository: SavedRepository

    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLogins: Set<String> = []
    @State private var saveState: SaveState = .idle

    var body: some View {
        NavigationStack {
            List(candidates, id: \.self, selection: $selectedLogins) { login in
                HStack {
                    Label(login, systemImage: "person")
                    Spacer()
                    if selectedLogins.contains(login) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedLogins.contains(login) {
                        selectedLogins.remove(login)
                    } else {
                        selectedLogins.insert(login)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        "No Candidates",
                        systemImage: "person.slash",
                        description: Text("No individual code owners found for this file. Team handles cannot be assigned.")
                    )
                }
            }
            .navigationTitle("Assign To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(saveState == .saving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if case .error(let message) = saveState {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                }
            }
        }
        .onAppear {
            selectedLogins = Set(alert.assignedLogins)
        }
    }

    // MARK: - Candidates

    /// All user (non-team) codeowner logins for this alert's manifest path,
    /// plus any currently assigned logins not found in CODEOWNERS (e.g. set via GitHub web).
    private var candidates: [String] {
        let resolvedHandles = CodeownerResolver.resolve(
            filePath: alert.manifestPath ?? "",
            codeowners: repository.codeowners
        )
        let codeownerLogins = resolvedHandles
            .filter { !$0.contains("/") }           // drop team handles (@org/team)
            .map { $0.hasPrefix("@") ? String($0.dropFirst()) : $0 }

        // Include current assignees not in the resolved list so they can be deselected.
        let extra = alert.assignedLogins.filter { !codeownerLogins.contains($0) }
        return (codeownerLogins + extra).sorted()
    }

    // MARK: - Save

    @MainActor
    private func save() async {
        saveState = .saving
        let service = SecurityService(rest: RESTClient(tokenProvider: authService.tokenProvider))
        do {
            let updatedLogins = try await service.updateAssignees(
                alertNumber: alert.alertNumber,
                logins: Array(selectedLogins),
                owner: repository.owner,
                repo: repository.name
            )
            alert.assignedLogins = updatedLogins
            try? modelContext.save()
            dismiss()
        } catch {
            saveState = .error("Failed to update assignees. Check your connection and try again.")
        }
    }
}

// MARK: - SaveState

private enum SaveState: Equatable {
    case idle
    case saving
    case error(String)
}
