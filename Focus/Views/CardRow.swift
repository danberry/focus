//
//  CardRow.swift
//  Focus
//
//  Created by Dan Berry on 4/11/26.
//

import SwiftUI

// MARK: - CardRow

/// Wraps content in a glass-effect card section with consistent spacing.
struct CardRow<Content: View>: View {

    // MARK: - Properties

    /// The view content to display inside the card.
    @ViewBuilder let content: Content

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Section {
            content
                .glassCardEffect()
        }
        .listRowSeparator(.hidden)
        .listSectionSpacing(18)
    }

}

// MARK: - View + GlassCardEffect

extension View {

    /// Applies horizontal and vertical padding with a rounded glass background.
    func glassCardEffect() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(in: RoundedRectangle(cornerRadius: 26))
    }

}

#Preview {
    CardRow {
        LabeledContent { } label: {
            Text("Hello")
            Text("World")
        }
    }
}
