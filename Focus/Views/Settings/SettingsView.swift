import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(AuthenticationService.self) private var authService
    @State private var newToken = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
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

                Section {
                    NavigationLink("Organizations") {
                        OrganizationsView()
                    }
                    NavigationLink("Disciplines") {
                        DisciplinesView()
                    }
                }

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
