import SwiftUI

/// Live, scalable visual preview of a `DrinkLook`. Layers, bottom→top:
///   1. Liquid fill (clipped to vessel interior), striped if empty
///   2. Ice layer (clipped to vessel interior)
///   3. Vessel outline / wall stroke
///   4. Citrus (one or many)
///   5. Garnishes
///   6. Extras (straws, umbrellas, stirrers) layered last
///
/// Accepts an optional `DrinkLook?` — when nil, renders an empty rocks glass.
struct DrinkPreviewView: View {
    private let look: DrinkLook?

    init(look: DrinkLook?) {
        self.look = look
    }

    var body: some View {
        // Effective look defaults — used when `look` is nil so the view still
        // renders as a sensible empty glass.
        let vessel = look?.vessel ?? .rocks
        let hex = look?.drinkColorHex ?? ""
        let hasLiquid = look?.hasLiquid ?? false
        let ice = look?.ice ?? .none
        let citrus = look?.citrus ?? []
        let garnishes = look?.garnishes ?? []
        let extras = look?.extras ?? []
        let shape = VesselShape(vessel: vessel)

        GeometryReader { geo in
            // The vessel is drawn into a portrait box of roughly 0.72 width-of-geo
            // by full height, centered horizontally.
            let drawSize = CGSize(
                width: geo.size.width * 0.78,
                height: geo.size.height
            )
            let origin = CGPoint(
                x: (geo.size.width - drawSize.width) / 2,
                y: 0
            )

            ZStack(alignment: .topLeading) {
                // 1. Liquid (clipped to vessel interior)
                liquidLayer(hex: hex, hasLiquid: hasLiquid, vessel: vessel)
                    .frame(width: drawSize.width, height: drawSize.height)
                    .clipShape(shape)
                    .offset(x: origin.x, y: origin.y)

                // 2. Ice (clipped to vessel interior, only above the liquid line)
                IceLayerView(ice: ice)
                    .frame(width: drawSize.width, height: drawSize.height)
                    .clipShape(shape)
                    .offset(x: origin.x, y: origin.y)

                // 3. Vessel outline / wall
                shape
                    .stroke(Color.white.opacity(0.95), lineWidth: 1.8)
                    .frame(width: drawSize.width, height: drawSize.height)
                    .offset(x: origin.x, y: origin.y)

                // 3b. Rim band for sugar/salt (drawn above wall, below garnish)
                rimDust(for: garnishes, in: drawSize, origin: origin, vessel: vessel)

                // 4. Citrus garnishes — drape across rim
                ForEach(Array(citrus.enumerated()), id: \.offset) { idx, c in
                    let layout = citrusLayout(index: idx, total: citrus.count,
                                              drawSize: drawSize, origin: origin,
                                              citrus: c, vessel: vessel)
                    CitrusView(citrus: c)
                        .frame(width: layout.size, height: layout.size)
                        .rotationEffect(.degrees(layout.rotation))
                        .position(x: layout.x, y: layout.y)
                }

                // 5. Garnishes (skip rim variants, those are handled above)
                ForEach(Array(garnishes.enumerated()), id: \.offset) { idx, g in
                    if g != .sugarRim && g != .saltRim {
                        let layout = garnishLayout(index: idx, total: garnishes.count,
                                                   drawSize: drawSize, origin: origin,
                                                   garnish: g, vessel: vessel)
                        GarnishView(garnish: g)
                            .frame(width: layout.size, height: layout.size)
                            .rotationEffect(.degrees(layout.rotation))
                            .position(x: layout.x, y: layout.y)
                    }
                }

                // 6. Extras
                ForEach(Array(extras.enumerated()), id: \.offset) { idx, e in
                    extraView(e, drawSize: drawSize, origin: origin, index: idx)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: Layers

    @ViewBuilder
    private func liquidLayer(hex: String, hasLiquid: Bool, vessel: Vessel) -> some View {
        if hasLiquid {
            Color(hex: hex)
                .overlay(
                    // Subtle inner highlight along the top edge of the liquid
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), .clear],
                        startPoint: .top, endPoint: .center)
                )
        } else {
            // Striped/empty look — diagonal pinstripes on parchment.
            ZStack {
                Color.white.opacity(0.10)
                Canvas { ctx, size in
                    let stripe: CGFloat = 8
                    let count = Int((size.width + size.height) / stripe) + 2
                    for i in 0..<count {
                        let x = CGFloat(i) * stripe - size.height
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                        ctx.stroke(p, with: .color(.white.opacity(0.25)), lineWidth: 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rimDust(for garnishes: [Garnish],
                         in drawSize: CGSize,
                         origin: CGPoint,
                         vessel: Vessel) -> some View {
        if let rim = garnishes.first(where: { $0 == .sugarRim || $0 == .saltRim }) {
            RimDustShape(color: rim == .saltRim ? .white : Color(hex: "#F8EBC8"))
                .frame(width: drawSize.width * 0.7, height: drawSize.height * 0.06)
                .position(
                    x: origin.x + drawSize.width / 2,
                    y: origin.y + drawSize.height * rimY(for: vessel) + 4
                )
        }
    }

    @ViewBuilder
    private func extraView(_ extra: Extra,
                           drawSize: CGSize,
                           origin: CGPoint,
                           index: Int) -> some View {
        switch extra {
        case .straw:
            Capsule()
                .fill(Color(hex: "#E2645E"))
                .frame(width: drawSize.width * 0.05, height: drawSize.height * 0.55)
                .rotationEffect(.degrees(14))
                .position(
                    x: origin.x + drawSize.width * 0.62,
                    y: origin.y + drawSize.height * 0.38
                )
        case .umbrella:
            UmbrellaView()
                .frame(width: drawSize.width * 0.30, height: drawSize.width * 0.30)
                .rotationEffect(.degrees(-18))
                .position(
                    x: origin.x + drawSize.width * 0.30,
                    y: origin.y + drawSize.height * 0.22
                )
        case .stirrer:
            Rectangle()
                .fill(Color(hex: "#3A3640"))
                .frame(width: drawSize.width * 0.018, height: drawSize.height * 0.6)
                .rotationEffect(.degrees(-10))
                .position(
                    x: origin.x + drawSize.width * 0.42,
                    y: origin.y + drawSize.height * 0.36
                )
        }
    }

    // MARK: Layouts

    /// Returns the normalized Y where the rim sits for each vessel — used to
    /// place garnish & rim dust.
    private func rimY(for vessel: Vessel) -> CGFloat {
        switch vessel {
        case .rocks:        return 0.18
        case .collins:      return 0.06
        case .highball:     return 0.10
        case .snifter:      return 0.18
        case .coupe:        return 0.15
        case .martini:      return 0.10
        case .nickAndNora:  return 0.18
        case .hurricane:    return 0.08
        case .copperMug:    return 0.16
        case .wine:         return 0.12
        case .flute:        return 0.08
        case .shot:         return 0.46
        case .tiki:         return 0.10
        }
    }

    private struct ItemLayout {
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var rotation: Double
    }

    private func citrusLayout(index: Int, total: Int,
                              drawSize: CGSize, origin: CGPoint,
                              citrus: Citrus, vessel: Vessel) -> ItemLayout {
        let rim = origin.y + drawSize.height * rimY(for: vessel)
        let size = drawSize.width * sizeFraction(for: citrus)
        let isFloating = citrus == .lemonWheel || citrus == .limeWheel || citrus == .orangeWheel
        // Alternate sides for multiple garnishes
        let side: CGFloat = (index % 2 == 0) ? -1 : 1
        let dx = drawSize.width * 0.20 * side
        let y: CGFloat
        if isFloating {
            // Float on the liquid surface
            y = rim + drawSize.height * 0.05
        } else {
            // Drape over rim
            y = rim - size * 0.10
        }
        let x = origin.x + drawSize.width / 2 + dx
        let rotation: Double = (citrus == .lemonTwist || citrus == .orangeTwist || citrus == .limeTwist) ? Double(side) * 10 : 0
        return .init(x: x, y: y, size: size, rotation: rotation)
    }

    private func garnishLayout(index: Int, total: Int,
                               drawSize: CGSize, origin: CGPoint,
                               garnish: Garnish, vessel: Vessel) -> ItemLayout {
        let rim = origin.y + drawSize.height * rimY(for: vessel)
        let size = drawSize.width * sizeFraction(for: garnish)
        let side: CGFloat = (index % 2 == 0) ? 1 : -1
        let dx = drawSize.width * 0.18 * side
        let x = origin.x + drawSize.width / 2 + dx
        // Most garnishes sit just above the rim
        let y = rim - size * 0.35
        return .init(x: x, y: y, size: size, rotation: 0)
    }

    private func sizeFraction(for citrus: Citrus) -> CGFloat {
        switch citrus {
        case .lemonWheel, .limeWheel, .orangeWheel: return 0.30
        case .lemonWedge, .limeWedge:               return 0.28
        default:                                    return 0.32
        }
    }

    private func sizeFraction(for garnish: Garnish) -> CGFloat {
        switch garnish {
        case .cherry, .olive:           return 0.16
        case .mintSprig, .rosemary:     return 0.32
        case .cinnamonStick:            return 0.28
        case .starAnise:                return 0.18
        case .cucumber:                 return 0.28
        case .edibleFlower:             return 0.22
        case .sugarRim, .saltRim:       return 0.0  // handled separately
        }
    }

    // MARK: Accessibility

    private var accessibilityDescription: String {
        guard let look = look else { return "Empty rocks glass" }
        var parts: [String] = [look.vessel.display]
        if look.hasLiquid {
            parts.append("with liquid")
        } else {
            parts.append("empty")
        }
        if let ice = look.ice, ice != .none {
            parts.append("\(ice.display.lowercased()) ice")
        }
        if !look.citrus.isEmpty {
            parts.append("garnished with " + look.citrus.map(\.display).joined(separator: ", "))
        }
        if !look.garnishes.isEmpty {
            parts.append(look.garnishes.map(\.display).joined(separator: ", "))
        }
        return parts.joined(separator: ", ")
    }
}

/// Tiny umbrella graphic.
private struct UmbrellaView: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Stick
                Rectangle()
                    .fill(Color(hex: "#3A3640"))
                    .frame(width: s * 0.04, height: s * 1.2)
                    .offset(y: s * 0.25)
                // Canopy — pie slices
                ForEach(0..<6) { i in
                    Path { p in
                        p.move(to: CGPoint(x: s / 2, y: s / 2))
                        p.addArc(center: CGPoint(x: s / 2, y: s / 2),
                                 radius: s / 2,
                                 startAngle: .degrees(180 + Double(i) * 30),
                                 endAngle: .degrees(180 + Double(i + 1) * 30),
                                 clockwise: false)
                        p.closeSubpath()
                    }
                    .fill(i % 2 == 0 ? Color(hex: "#E27F2A") : Color(hex: "#E8C547"))
                }
            }
        }
    }
}

#Preview("Empty") {
    DrinkPreviewView(look: nil)
        .frame(width: 240, height: 280)
        .background(Color(hex: "#3F5C5F"))
}

#Preview("Old Fashioned") {
    let look = DrinkLook(
        vessel: .rocks,
        drinkColorHex: "#965D2D",
        ice: .huge,
        citrus: [.orangeTwist],
        garnishes: [.cherry]
    )
    return DrinkPreviewView(look: look)
        .frame(width: 240, height: 280)
        .background(Color(hex: "#B14A1E"))
}

#Preview("Mojito") {
    let look = DrinkLook(
        vessel: .collins,
        drinkColorHex: "#B5D0C5",
        ice: .crushed,
        citrus: [.limeWheel],
        garnishes: [.mintSprig],
        extras: [.straw]
    )
    return DrinkPreviewView(look: look)
        .frame(width: 240, height: 280)
        .background(Color(hex: "#8A9F76"))
}
