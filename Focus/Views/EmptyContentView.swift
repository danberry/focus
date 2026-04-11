import SwiftUI

// MARK: - EmptyContentView

struct EmptyContentView: View {
    private let title: String
    private let systemImage: String
    private let name: String?

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
        self.name = nil
    }
    
    init(_ title: String, named: String) {
        self.title = title
        self.systemImage = ""
        self.name = named
    }

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
    
    var image: Image {
        if let name {
            Image(name)
        }
        else {
            Image(systemName: systemImage)
        }
    }
    
}
