import SwiftUI

// MARK: - EmptyContentView

struct EmptyContentView: View {
    private let title: String
    private let systemImage: String

    private let greyGradient = LinearGradient(
        colors: [Color("AccentGrey"), Color("AccentGrey").opacity(0.5)],
        startPoint: .top,
        endPoint: .bottom
    )

    private let redGradient = LinearGradient(
        colors: [Color("AccentRed"), Color("AccentRed").opacity(0.5)],
        startPoint: .top,
        endPoint: .bottom
    )

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage)
            .symbolRenderingMode(.palette)
            .foregroundStyle(greyGradient, redGradient)
    }
}
