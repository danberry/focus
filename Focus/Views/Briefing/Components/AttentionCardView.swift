import SwiftUI

// MARK: - AttentionCardView

/// A full-width attention card shown in the briefing's hero ranked list.
///
/// Each card surfaces one ``BriefingAttentionItem`` with a tone-colored eyebrow,
/// title, meta line, and a tone-matched call-to-action button.
struct AttentionCardView: View {

    // MARK: - Properties

    /// The attention item to render.
    let item: BriefingAttentionItem

    /// Closure invoked when the action button is tapped. Defaults to a no-op.
    var onAction: () -> Void = {}

    // MARK: - Helpers

    private var toneColor: Color {
        switch item.tone {
        case .red: return BriefingColor.red2
        case .blue: return BriefingColor.blue2
        case .neutral: return BriefingColor.ink2
        }
    }

    // MARK: - Body

    /// The view's content.
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text(item.n)
                    .font(BriefingFont.eyebrow)
                    .foregroundStyle(toneColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(.init(item.title))
                        .font(BriefingFont.attentionTitle)
                        .foregroundStyle(BriefingColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.meta)
                        .font(BriefingFont.meta)
                        .foregroundStyle(toneColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button(action: onAction) {
                Text(item.actionLabel)
                    .font(BriefingFont.eyebrow)
                    .foregroundStyle(.foreground(item.tone))
            }
            .buttonStyle(.glassProminent)
            .tint(.background(item.tone))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .briefingCard(tone: item.tone)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 10) {
        ForEach(Array(Briefing.placeholder.attention.enumerated()), id: \.offset) { _, item in
            AttentionCardView(item: item)
        }
    }
    .padding()
}
