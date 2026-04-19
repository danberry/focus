import SwiftUI

// MARK: - BriefingAttentionDetailView

/// The detail view pushed when a briefing attention card's action button is tapped on iPad.
struct BriefingAttentionDetailView: View {

    // MARK: - Properties

    /// The attention item driving the detail content.
    let item: BriefingAttentionItem

    // MARK: - Body

    /// The view's content.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BriefingChipView(label: "§ \(item.n)", tone: item.tone)

                Text(item.title)
                    .font(BriefingFont.sectionVerdict)
                    .foregroundStyle(BriefingColor.ink)

                Text(item.meta)
                    .font(BriefingFont.meta)
                    .foregroundStyle(BriefingColor.ink3)
                
                Spacer()
            }
            .padding(BriefingLayout.gutter)
            .frame(maxWidth: .infinity)
        }
        .background(BriefingColor.paper)
    }
}
