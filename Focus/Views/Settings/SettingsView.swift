import SwiftUI

// MARK: - SettingsView

/// Displays controls for updating the GitHub personal access token and navigating to app configuration.
struct SettingsView: View {

    // MARK: - Properties

    /// The authentication service, used to sign in with a new token or sign out.
    @Environment(AuthenticationService.self) private var authService

    /// The token string entered by the user before submission.
    @State private var newToken = ""

    /// Whether the most recent token update succeeded, controlling success message visibility.
    @State private var showSuccess = false

    // MARK: - Body

    /// The view's content.
    var body: some View {
        NavigationStack {
            Form {
                // MARK: GitHub Token

                Section {
                    SecureField("New personal access token", text: $newToken)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: newToken) {
                            showSuccess = false
                        }
                } header: {
                    Text("GitHub Token")
                } footer: {
                    Text("Enter a new token to replace the current one. The token must have repo, read:org, and read:user scopes.")
                }

                // MARK: Update Token

                Section {
                    Button {
                        Task {
                            showSuccess = false
                            await authService.signIn(token: newToken)
                            if authService.error == nil {
                                newToken = ""
                                showSuccess = true
                            }
                        }
                    } label: {
                        if authService.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Update Token")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(newToken.isEmpty || authService.isLoading)
                }

                if showSuccess {
                    Section {
                        Label("Token updated successfully.", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                if let error = authService.error {
                    Section {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                // MARK: Navigation

                Section {
                    NavigationLink("Organizations") {
                        OrganizationsView()
                    }
                    NavigationLink("Departments") {
                        DepartmentsView()
                    }
                    NavigationLink("Disciplines") {
                        DisciplinesView()
                    }
                }

                // MARK: Sign Out

                Section {
                    Button(role: .destructive) {
                        authService.signOut()
                    } label: {
                        Text("Sign Out")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Settings")
        }
    }
}
