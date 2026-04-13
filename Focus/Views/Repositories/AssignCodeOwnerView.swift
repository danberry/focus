import SwiftUI

// MARK: - AssignCodeOwnerView

/// A sheet for selecting assignees for a Dependabot alert from the repository's code owners.
struct AssignCodeOwnerView: View {

    // MARK: - Properties

    /// The Dependabot alert to assign owners to.
    let alert: DependabotAlert

    /// The repository that owns the alert.
    let repository: SavedRepository

    /// The authentication service providing the API token.
    @Environment(AuthenticationService.self) private var authService

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The dismiss action for closing the sheet.
    @Environment(\.dismiss) private var dismiss

    /// The resolved list of candidate logins available for assignment.
    @State private var candidates: [String] = []

    /// Whether the candidate list is currently loading.
    @State private var isLoadingCandidates = true

    /// The set of currently selected assignee logins.
    @State private var selectedLogins: Set<String> = []

    /// The current state of the save operation.
    @State private var saveState: SaveState = .idle

    // MARK: - Body

    /// The view's content.
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
                if isLoadingCandidates {
                    ProgressView()
                } else if candidates.isEmpty {
                    ContentUnavailableView(
                        "No Candidates",
                        systemImage: "person.slash",
                        description: Text("No code owners found for this file.")
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
        .task {
            await loadCandidates()
        }
    }

    // MARK: - Helpers

    /// Resolves CODEOWNERS handles for the alert's manifest path to individual GitHub logins.
    private func loadCandidates() async {
        let resolvedHandles = CodeownerResolver.resolve(
            filePath: alert.manifestPath ?? "",
            codeowners: repository.codeowners
        )
        let rest = RESTClient(tokenProvider: authService.tokenProvider)
        let service = CodeownerEmailService(rest: rest)
        let logins = await service.resolveLogins(handles: resolvedHandles)

        // Include current assignees not resolved from CODEOWNERS so they can be deselected.
        let extra = alert.assignedLogins.filter { !logins.contains($0) }
        candidates = (logins + extra).sorted()
        isLoadingCandidates = false
    }

    /// Patches the alert's assignees via the GitHub REST API and dismisses on success.
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

/// The state of the assignee save operation.
private enum SaveState: Equatable {
    /// No save operation is in progress.
    case idle
    /// A save operation is currently running.
    case saving
    /// The save operation failed with the associated error message.
    case error(String)
}
