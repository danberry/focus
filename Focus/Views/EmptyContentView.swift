import SwiftUI

// MARK: - EmptyContentView

/// A reusable empty-state view that displays a title with either a system symbol or a named image asset.
struct EmptyContentView: View {

    // MARK: - Properties

    /// The title text displayed below the icon.
    private let title: String

    /// The SF Symbol name used when no named image is provided.
    private let systemImage: String

    /// The name of a custom image asset, or `nil` when using an SF Symbol.
    private let name: String?

    // MARK: - Init

    /// Creates a view with an SF Symbol icon.
    ///
    /// - Parameters:
    ///   - title: The title text displayed below the icon.
    ///   - systemImage: The SF Symbol name to display.
    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
        self.name = nil
    }

    /// Creates a view with a named image asset.
    ///
    /// - Parameters:
    ///   - title: The title text displayed below the icon.
    ///   - named: The name of the image asset to display.
    init(_ title: String, named: String) {
        self.title = title
        self.systemImage = ""
        self.name = named
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                image
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.accentedRed.gradient, .accentedGray.gradient)
            }
        }
        .listRowSeparator(.hidden)
    }

    // MARK: - Helpers

    /// The icon resolved from either the named asset or the SF Symbol.
    var image: Image {
        if let name {
            Image(name)
        }
        else {
            Image(systemName: systemImage)
        }
    }

}
