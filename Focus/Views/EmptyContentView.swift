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
        ContentUnavailableView(title, systemImage: systemImage)
    }
}
