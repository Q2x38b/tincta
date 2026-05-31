import SwiftUI
import SwiftData

/// Full-screen sheet that lets the user compose the visual look of a drink:
/// vessel, drink color, ice, citrus, garnishes, extras. The live preview at the
/// top updates instantly as options are tapped. DONE writes back to the bound
/// DrinkLook.
struct DrinkBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: BuilderViewModel

    /// The Recipe's chosen background hex — used as the sheet background and to
    /// pick a contrasting foreground (per design Image 5).
    private let backgroundHex: String

    init(look: DrinkLook?, backgroundHex: String = "#3F5C5F") {
        _vm = State(initialValue: BuilderViewModel(look: look))
        self.backgroundHex = backgroundHex
    }

    var body: some View {
        let bg = Color(hex: backgroundHex)
        let fg = contrastingForeground(forHex: backgroundHex)

        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: DONE button (left)
                HStack {
                    Button {
                        vm.commit()
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(.tinctaUILabel(14))
                            .tracking(2)
                            .foregroundStyle(fg)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .accessibilityLabel("Done editing drink look")
                    Spacer()
                }
                .padding(.top, 4)

                // Live preview
                DrinkPreviewView(look: vm.stagedLook)
                    .frame(height: 280)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                // Option sections
                ScrollView {
                    VStack(spacing: 28) {
                        OptionSection(label: "VESSEL", foreground: fg) {
                            ForEach(Vessel.allCases) { v in
                                OptionDot(
                                    isSelected: vm.vessel == v,
                                    foreground: fg,
                                    accessibilityLabel: v.display
                                ) {
                                    vm.vessel = v
                                } content: {
                                    VesselShape(vessel: v)
                                        .stroke(fg, lineWidth: 1.2)
                                        .padding(6)
                                }
                            }
                        }

                        OptionSection(label: "DRINK COLOR", foreground: fg) {
                            ForEach(LiquidPalette.hexes, id: \.self) { hex in
                                OptionDot(
                                    isSelected: vm.drinkColorHex == hex,
                                    foreground: fg,
                                    accessibilityLabel: hex.isEmpty ? "No liquid" : hex
                                ) {
                                    vm.drinkColorHex = hex
                                } content: {
                                    LiquidSwatch(hex: hex)
                                }
                            }
                        }

                        OptionSection(label: "ICE", foreground: fg) {
                            ForEach(IceType.allCases) { ice in
                                OptionDot(
                                    isSelected: vm.ice == ice,
                                    foreground: fg,
                                    accessibilityLabel: ice.display
                                ) {
                                    vm.ice = ice
                                } content: {
                                    IceOptionGlyph(ice: ice, foreground: fg)
                                }
                            }
                        }

                        OptionSection(label: "CITRUS", foreground: fg) {
                            ForEach(Citrus.allCases) { c in
                                OptionDot(
                                    isSelected: vm.citrus.contains(c),
                                    foreground: fg,
                                    accessibilityLabel: c.display
                                ) {
                                    vm.toggle(c)
                                } content: {
                                    CitrusView(citrus: c)
                                        .padding(8)
                                }
                            }
                        }

                        OptionSection(label: "GARNISHES", foreground: fg) {
                            ForEach(Garnish.allCases) { g in
                                OptionDot(
                                    isSelected: vm.garnishes.contains(g),
                                    foreground: fg,
                                    accessibilityLabel: g.display
                                ) {
                                    vm.toggle(g)
                                } content: {
                                    GarnishView(garnish: g)
                                        .padding(8)
                                }
                            }
                        }

                        OptionSection(label: "EXTRAS", foreground: fg) {
                            ForEach(Extra.allCases) { e in
                                OptionDot(
                                    isSelected: vm.extras.contains(e),
                                    foreground: fg,
                                    accessibilityLabel: e.display
                                ) {
                                    vm.toggle(e)
                                } content: {
                                    ExtraGlyph(extra: e, foreground: fg)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Section row

/// A labeled horizontal scroller of circular option dots.
private struct OptionSection<Content: View>: View {
    let label: String
    let foreground: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.tinctaUILabel(12))
                .tracking(2.4)
                .foregroundStyle(foreground.opacity(0.85))
                .padding(.horizontal, 24)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    content()
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Selectable circular option

private struct OptionDot<Content: View>: View {
    let isSelected: Bool
    let foreground: Color
    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    private let diameter: CGFloat = 64

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? foreground : Color.clear)
                Circle()
                    .strokeBorder(foreground, lineWidth: 1.4)
                content()
                    .frame(width: diameter, height: diameter)
                    .foregroundStyle(isSelected ? Color(hex: "#1A1A1A") : foreground)
                    .blendMode(isSelected ? .normal : .normal)
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .frame(minWidth: 44, minHeight: 44)
    }
}

// MARK: - Glyphs for liquid / ice / extras inside option dots

private struct LiquidSwatch: View {
    let hex: String
    var body: some View {
        if hex.isEmpty {
            // Striped empty swatch
            Circle()
                .fill(Color.clear)
                .overlay(
                    Canvas { ctx, size in
                        let stripe: CGFloat = 6
                        let count = Int((size.width + size.height) / stripe) + 2
                        for i in 0..<count {
                            let x = CGFloat(i) * stripe - size.height
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                            ctx.stroke(p, with: .color(.white.opacity(0.6)), lineWidth: 1)
                        }
                    }
                    .clipShape(Circle())
                )
                .padding(8)
        } else {
            Circle()
                .fill(Color(hex: hex))
                .padding(8)
        }
    }
}

private struct IceOptionGlyph: View {
    let ice: IceType
    let foreground: Color

    var body: some View {
        Group {
            switch ice {
            case .huge:
                RoundedRectangle(cornerRadius: 4)
                    .stroke(foreground, lineWidth: 1.4)
                    .frame(width: 28, height: 28)
            case .cubes:
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2).stroke(foreground, lineWidth: 1.2).frame(width: 12, height: 12)
                    RoundedRectangle(cornerRadius: 2).stroke(foreground, lineWidth: 1.2).frame(width: 12, height: 12)
                }
            case .crushed:
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle().stroke(foreground, lineWidth: 1).frame(width: 5, height: 5)
                        }
                    }
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle().stroke(foreground, lineWidth: 1).frame(width: 5, height: 5)
                        }
                    }
                }
            case .none:
                // Slashed circle — "no ice"
                ZStack {
                    Circle().stroke(foreground.opacity(0.4), lineWidth: 1)
                    Path { p in
                        p.move(to: CGPoint(x: 6, y: 26))
                        p.addLine(to: CGPoint(x: 26, y: 6))
                    }
                    .stroke(foreground.opacity(0.6), lineWidth: 1.4)
                }
                .frame(width: 30, height: 30)
            }
        }
    }
}

private struct ExtraGlyph: View {
    let extra: Extra
    let foreground: Color
    var body: some View {
        switch extra {
        case .straw:
            Capsule().fill(foreground).frame(width: 6, height: 36).rotationEffect(.degrees(12))
        case .umbrella:
            Image(systemName: "umbrella.fill")
                .font(.system(size: 22))
                .foregroundStyle(foreground)
        case .stirrer:
            Rectangle().fill(foreground).frame(width: 2, height: 38)
        }
    }
}

// MARK: - Preview

#Preview("Drink Builder") {
    DrinkBuilderView(
        look: DrinkLook(
            vessel: .rocks,
            drinkColorHex: TinctaPalette.amberLiquid.hex,
            ice: .huge,
            citrus: [.orangeTwist],
            garnishes: [.cherry]
        ),
        backgroundHex: TinctaPalette.rust.hex
    )
    .modelContainer(TinctaModelContainer.makePreview())
}
