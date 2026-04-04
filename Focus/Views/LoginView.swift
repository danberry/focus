import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationService.self) private var authService
    @State private var tokenInput = ""

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
            .navigationTitle("Focus")
        }
    }
}
