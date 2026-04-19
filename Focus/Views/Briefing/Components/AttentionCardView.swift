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
                    Text(item.title)
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
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
            }
            .buttonStyle(BriefingActionButtonStyle(tone: item.tone))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .briefingCard(tone: item.tone)
    }
}

// MARK: - BriefingActionButtonStyle

/// A capsule-shaped, tone-aware button style used by ``AttentionCardView``'s call to action.
private struct BriefingActionButtonStyle: ButtonStyle {

    // MARK: - Properties

    /// The semantic tone that drives the button's fill and label color.
    let tone: BriefingTone

    // MARK: - Body

    /// Builds the styled button label.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BriefingFont.eyebrow)
            .foregroundStyle(foreground)
            .background(Capsule().fill(background))
            .overlay(
                Capsule().strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    // MARK: - Helpers

    /// The button background fill for the current tone.
    private var background: Color {
        switch tone {
        case .red: return BriefingColor.red
        case .blue: return BriefingColor.blue
        case .neutral: return BriefingColor.paper
        }
    }

    /// The label foreground color for the current tone.
    private var foreground: Color {
        switch tone {
        case .red, .blue: return .white
        case .neutral: return BriefingColor.ink
        }
    }

    /// The border color used for the neutral tone outline.
    private var borderColor: Color {
        switch tone {
        case .red, .blue: return .clear
        case .neutral: return BriefingColor.rule
        }
    }

    /// The border width used for the neutral tone outline.
    private var borderWidth: CGFloat {
        switch tone {
        case .red, .blue: return 0
        case .neutral: return 1
        }
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
