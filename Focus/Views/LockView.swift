import SwiftUI

// MARK: - LockView

struct LockView: View {
    @Environment(AuthenticationService.self) private var authService

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Focus is Locked")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Your GitHub token is protected by Face ID.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let error = authService.error {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task {
                    await authService.authenticateAndLoadToken()
                }
            } label: {
                if authService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(authService.error == nil ? "Unlock" : "Try Again")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authService.isLoading)
            .padding(.horizontal, 48)

            Spacer()
        }
        .onAppear {
            Task {
                await authService.authenticateAndLoadToken()
            }
        }
    }
}
