import SwiftUI

// MARK: - EmptyContentView

struct EmptyContentView: View {
    private let title: String
    private let systemImage: String

    private let greyGradient = LinearGradient(
        colors: [.accentedGray, .accentedGray.opacity(0.5)],
        startPoint: .top,
        endPoint: .bottom
    )

    private let redGradient = LinearGradient(
        colors: [.accentedRed, .accentedRed.opacity(0.5)],
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
