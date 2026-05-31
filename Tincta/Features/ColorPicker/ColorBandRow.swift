import SwiftUI

/// A single full-bleed color band in the Choose Color picker.
/// Tapping the row invokes `onTap`. When `isSelected` is true, a white
/// checkmark appears on the right (color tuned for contrast against the band).
struct ColorBandRow: View {
    let swatch: TinctaSwatch
    let isSelected: Bool
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Color(hex: swatch.hex)

                HStack {
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(checkmarkColor)
                            .padding(.trailing, 28)
                            .accessibilityLabel("Selected")
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(swatch.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Checkmark color: contrasting foreground for the band's hex so the mark
    /// is visible against pale creams and dark slates alike. Defaults to white
    /// on most bands as per the design mock (Image 7).
    private var checkmarkColor: Color {
        contrastingForeground(forHex: swatch.hex)
    }
}

#Preview("Bands") {
    VStack(spacing: 0) {
        ColorBandRow(swatch: TinctaPalette.all[0], isSelected: false, height: 120) {}
        ColorBandRow(swatch: TinctaPalette.rust, isSelected: true, height: 120) {}
        ColorBandRow(swatch: TinctaPalette.cream, isSelected: false, height: 120) {}
    }
}
