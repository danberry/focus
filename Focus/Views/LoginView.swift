import SwiftUI

// MARK: - LoginView

/// Presents a form for entering a GitHub personal access token to authenticate.
struct LoginView: View {

    // MARK: - Properties

    /// The authentication service, injected from the environment.
    @Environment(AuthenticationService.self) private var authService

    /// The dismiss action, used to close the sheet on successful sign-in or cancellation.
    @Environment(\.dismiss) private var dismiss

    /// The token text entered by the user.
    @State private var tokenInput = ""

    // MARK: - Body

    /// The view's content.
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Personal access token", text: $tokenInput)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("GitHub Authentication")
                } footer: {
                    Text("Enter a personal access token with repo, read:org, and read:user scopes.")
                }

                Section {
                    Button {
                        Task {
                            await authService.signIn(token: tokenInput)
                        }
                    } label: {
                        if authService.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(tokenInput.isEmpty || authService.isLoading)
                }

                if let error = authService.error {
                    Section {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("GitHub Token")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(authService.isLoading)
                }
            }
            .onChange(of: authService.authState) { _, newState in
                if newState == .authenticated {
                    dismiss()
                }
            }
        }
    }
}
