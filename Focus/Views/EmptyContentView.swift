import SwiftUI

// MARK: - EmptyContentView

struct EmptyContentView: View {
    private let title: String
    private let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.accentedRed.gradient, .accentedGray.gradient)
            }
        }
        .listRowSeparator(.hidden)
    }
}
