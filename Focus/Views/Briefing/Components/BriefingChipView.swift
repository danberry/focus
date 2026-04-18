import SwiftUI

// MARK: - BriefingChipView

/// A small uppercase capsule label used to mark briefing sections and attention cards.
///
/// The chip's fill, border, and foreground colors are derived from the supplied
/// ``BriefingTone``.
struct BriefingChipView: View {

    // MARK: - Properties

    /// The text shown inside the chip. Rendered uppercase.
    let label: String

    /// The semantic tone that drives the chip's color treatment.
    let tone: BriefingTone

    // MARK: - Body

    /// The view's content.
    var body: some View {
        Text(label)
            .font(BriefingFont.eyebrow)
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }

    // MARK: - Helpers

    /// The capsule fill color for the current tone.
    private var fill: Color {
        switch tone {
        case .red: return BriefingColor.redBg
        case .blue: return BriefingColor.blueBg
        case .neutral: return BriefingColor.paper2
        }
    }

    /// The capsule border color for the current tone.
    private var border: Color {
        switch tone {
        case .red: return BriefingColor.redBd
        case .blue: return BriefingColor.blueBd
        case .neutral: return BriefingColor.rule2
        }
    }

    /// The label foreground color for the current tone.
    private var foreground: Color {
        switch tone {
        case .red: return BriefingColor.red
        case .blue: return BriefingColor.blue
        case .neutral: return BriefingColor.ink3
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        BriefingChipView(label: "§ 01", tone: .red)
        BriefingChipView(label: "§ 02", tone: .blue)
        BriefingChipView(label: "§ 03", tone: .neutral)
    }
    .padding()
}
