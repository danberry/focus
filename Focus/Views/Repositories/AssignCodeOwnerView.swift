import SwiftUI

// MARK: - AssignCodeOwnerView

struct AssignCodeOwnerView: View {
    let alert: DependabotAlert
    let repository: SavedRepository

    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var candidates: [String] = []
    @State private var isLoadingCandidates = true
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

    // MARK: - Candidates

    /// Resolves all CODEOWNERS handles for this alert's manifest path to individual logins.
    /// Team handles (e.g. `@org/frontend-team`) are expanded to their members via the GitHub API.
    /// Currently assigned logins not found in CODEOWNERS are appended so they can be deselected.
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
