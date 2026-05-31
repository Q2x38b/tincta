import SwiftUI

/// Iconic silhouette of a barware vessel, drawn as a pure SwiftUI `Shape`.
///
/// Each vessel returns ONE closed silhouette path (no internal rim bumps, no
/// hidden subpaths) so the shape fills cleanly and strokes as a single
/// continuous outline. The rim ellipse, liquid highlight, and any other
/// decoration are layered on top by `DrinkPreviewView` — not baked into the
/// path — so the geometry never gets weird when filled.
struct VesselShape: Shape {
    let vessel: Vessel

    func path(in rect: CGRect) -> Path {
        let p = normalizedPath()
        let t = CGAffineTransform(scaleX: rect.width, y: rect.height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return p.applying(t)
    }

    func normalizedPath() -> Path {
        switch vessel {
        case .rocks:        return Self.rocks()
        case .collins:      return Self.collins()
        case .highball:     return Self.highball()
        case .snifter:      return Self.snifter()
        case .coupe:        return Self.coupe()
        case .martini:      return Self.martini()
        case .nickAndNora:  return Self.nickAndNora()
        case .hurricane:    return Self.hurricane()
        case .copperMug:    return Self.copperMug()
        case .wine:         return Self.wine()
        case .flute:        return Self.flute()
        case .shot:         return Self.shot()
        case .tiki:         return Self.tiki()
        }
    }

    /// Just the BOWL (the part that holds liquid) of the vessel, slightly
    /// inset. Used to clip the liquid layer in `DrinkPreviewView` so liquid
    /// never spills onto the stem or foot of a martini/coupe.
    func bowlPath() -> Path {
        switch vessel {
        case .rocks:        return Self.rocksBowl()
        case .collins:      return Self.collinsBowl()
        case .highball:     return Self.highballBowl()
        case .snifter:      return Self.snifterBowl()
        case .coupe:        return Self.coupeBowl()
        case .martini:      return Self.martiniBowl()
        case .nickAndNora:  return Self.nickAndNoraBowl()
        case .hurricane:    return Self.hurricaneBowl()
        case .copperMug:    return Self.copperMugBowl()
        case .wine:         return Self.wineBowl()
        case .flute:        return Self.fluteBowl()
        case .shot:         return Self.shotBowl()
        case .tiki:         return Self.tikiBowl()
        }
    }

    /// Where the rim sits in the normalised 0…1 coordinate space. Used so
    /// the preview view can draw a rim ellipse at exactly the right height.
    var rimLine: (left: CGPoint, right: CGPoint)? {
        switch vessel {
        case .rocks:        return (CGPoint(x: 0.12, y: 0.18), CGPoint(x: 0.88, y: 0.18))
        case .collins:      return (CGPoint(x: 0.30, y: 0.06), CGPoint(x: 0.70, y: 0.06))
        case .highball:     return (CGPoint(x: 0.24, y: 0.10), CGPoint(x: 0.76, y: 0.10))
        case .snifter:      return (CGPoint(x: 0.32, y: 0.20), CGPoint(x: 0.68, y: 0.20))
        case .coupe:        return (CGPoint(x: 0.10, y: 0.18), CGPoint(x: 0.90, y: 0.18))
        case .martini:      return (CGPoint(x: 0.10, y: 0.10), CGPoint(x: 0.90, y: 0.10))
        case .nickAndNora:  return (CGPoint(x: 0.22, y: 0.20), CGPoint(x: 0.78, y: 0.20))
        case .hurricane:    return (CGPoint(x: 0.22, y: 0.08), CGPoint(x: 0.78, y: 0.08))
        case .copperMug:    return (CGPoint(x: 0.18, y: 0.16), CGPoint(x: 0.72, y: 0.16))
        case .wine:         return (CGPoint(x: 0.22, y: 0.12), CGPoint(x: 0.78, y: 0.12))
        case .flute:        return (CGPoint(x: 0.40, y: 0.08), CGPoint(x: 0.60, y: 0.08))
        case .shot:         return (CGPoint(x: 0.30, y: 0.46), CGPoint(x: 0.70, y: 0.46))
        case .tiki:         return (CGPoint(x: 0.30, y: 0.10), CGPoint(x: 0.70, y: 0.10))
        }
    }

    // MARK: - Rocks (Old-Fashioned tumbler)

    private static func rocks() -> Path {
        var p = Path()
        let left: CGFloat = 0.12
        let right: CGFloat = 0.88
        let top: CGFloat = 0.18
        let bottom: CGFloat = 0.92
        let r: CGFloat = 0.05
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: left, y: bottom - r))
        p.addQuadCurve(to: CGPoint(x: left + r, y: bottom), control: CGPoint(x: left, y: bottom))
        p.addLine(to: CGPoint(x: right - r, y: bottom))
        p.addQuadCurve(to: CGPoint(x: right, y: bottom - r), control: CGPoint(x: right, y: bottom))
        p.addLine(to: CGPoint(x: right, y: top))
        p.closeSubpath()
        return p
    }
    private static func rocksBowl() -> Path { rocks() }

    // MARK: - Collins (tall narrow)

    private static func collins() -> Path {
        var p = Path()
        let left: CGFloat = 0.30
        let right: CGFloat = 0.70
        let top: CGFloat = 0.06
        let bottom: CGFloat = 0.94
        let r: CGFloat = 0.03
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: left, y: bottom - r))
        p.addQuadCurve(to: CGPoint(x: left + r, y: bottom), control: CGPoint(x: left, y: bottom))
        p.addLine(to: CGPoint(x: right - r, y: bottom))
        p.addQuadCurve(to: CGPoint(x: right, y: bottom - r), control: CGPoint(x: right, y: bottom))
        p.addLine(to: CGPoint(x: right, y: top))
        p.closeSubpath()
        return p
    }
    private static func collinsBowl() -> Path { collins() }

    // MARK: - Highball

    private static func highball() -> Path {
        var p = Path()
        let topLeft: CGFloat = 0.24
        let topRight: CGFloat = 0.76
        let botLeft: CGFloat = 0.28
        let botRight: CGFloat = 0.72
        let top: CGFloat = 0.10
        let bottom: CGFloat = 0.93
        let r: CGFloat = 0.03
        p.move(to: CGPoint(x: topLeft, y: top))
        p.addLine(to: CGPoint(x: botLeft, y: bottom - r))
        p.addQuadCurve(to: CGPoint(x: botLeft + r, y: bottom), control: CGPoint(x: botLeft, y: bottom))
        p.addLine(to: CGPoint(x: botRight - r, y: bottom))
        p.addQuadCurve(to: CGPoint(x: botRight, y: bottom - r), control: CGPoint(x: botRight, y: bottom))
        p.addLine(to: CGPoint(x: topRight, y: top))
        p.closeSubpath()
        return p
    }
    private static func highballBowl() -> Path { highball() }

    // MARK: - Snifter (balloon on a stubby stem)

    private static func snifter() -> Path {
        // Closed silhouette of the bowl ONLY (no stem subpath — keeps the
        // fill clean). The DrinkPreviewView draws the stem separately on top.
        snifterBowl()
    }
    private static func snifterBowl() -> Path {
        var p = Path()
        // Bowl rim
        p.move(to: CGPoint(x: 0.32, y: 0.20))
        p.addLine(to: CGPoint(x: 0.68, y: 0.20))
        // Right side bulges out and back in
        p.addCurve(to: CGPoint(x: 0.56, y: 0.78),
                   control1: CGPoint(x: 0.94, y: 0.34),
                   control2: CGPoint(x: 0.90, y: 0.74))
        p.addLine(to: CGPoint(x: 0.44, y: 0.78))
        // Left side mirror
        p.addCurve(to: CGPoint(x: 0.32, y: 0.20),
                   control1: CGPoint(x: 0.10, y: 0.74),
                   control2: CGPoint(x: 0.06, y: 0.34))
        p.closeSubpath()
        return p
    }

    // MARK: - Coupe (shallow bowl on stem)

    private static func coupe() -> Path { coupeBowl() }
    private static func coupeBowl() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.10, y: 0.18))
        p.addLine(to: CGPoint(x: 0.90, y: 0.18))
        p.addQuadCurve(to: CGPoint(x: 0.50, y: 0.52),
                       control: CGPoint(x: 0.90, y: 0.48))
        p.addQuadCurve(to: CGPoint(x: 0.10, y: 0.18),
                       control: CGPoint(x: 0.10, y: 0.48))
        p.closeSubpath()
        return p
    }

    // MARK: - Martini (V-cone on stem)

    private static func martini() -> Path { martiniBowl() }
    private static func martiniBowl() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.10, y: 0.10))
        p.addLine(to: CGPoint(x: 0.90, y: 0.10))
        p.addLine(to: CGPoint(x: 0.50, y: 0.52))
        p.closeSubpath()
        return p
    }

    // MARK: - Nick & Nora (small deeper coupe)

    private static func nickAndNora() -> Path { nickAndNoraBowl() }
    private static func nickAndNoraBowl() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.22, y: 0.20))
        p.addLine(to: CGPoint(x: 0.78, y: 0.20))
        p.addQuadCurve(to: CGPoint(x: 0.50, y: 0.58),
                       control: CGPoint(x: 0.82, y: 0.54))
        p.addQuadCurve(to: CGPoint(x: 0.22, y: 0.20),
                       control: CGPoint(x: 0.18, y: 0.54))
        p.closeSubpath()
        return p
    }

    // MARK: - Hurricane (curvy tulip)

    private static func hurricane() -> Path { hurricaneBowl() }
    private static func hurricaneBowl() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.22, y: 0.08))
        p.addLine(to: CGPoint(x: 0.78, y: 0.08))
        // Right wall: bulge out then narrow at waist
        p.addCurve(to: CGPoint(x: 0.68, y: 0.78),
                   control1: CGPoint(x: 0.98, y: 0.30),
                   control2: CGPoint(x: 0.70, y: 0.62))
        p.addLine(to: CGPoint(x: 0.32, y: 0.78))
        // Left wall mirror
        p.addCurve(to: CGPoint(x: 0.22, y: 0.08),
                   control1: CGPoint(x: 0.30, y: 0.62),
                   control2: CGPoint(x: 0.02, y: 0.30))
        p.closeSubpath()
        return p
    }

    // MARK: - Copper mug (with handle)

    private static func copperMug() -> Path { copperMugBowl() }
    private static func copperMugBowl() -> Path {
        var p = Path()
        let left: CGFloat = 0.18
        let right: CGFloat = 0.72
        let top: CGFloat = 0.16
        let bottom: CGFloat = 0.92
        let r: CGFloat = 0.04
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: left, y: bottom - r))
        p.addQuadCurve(to: CGPoint(x: left + r, y: bottom), control: CGPoint(x: left, y: bottom))
        p.addLine(to: CGPoint(x: right - r, y: bottom))
        p.addQuadCurve(to: CGPoint(x: right, y: bottom - r), control: CGPoint(x: right, y: bottom))
        p.addLine(to: CGPoint(x: right, y: top))
        p.closeSubpath()
        return p
    }

    // MARK: - Wine (tulip)

    private static func wine() -> Path { wineBowl() }
    private static func wineBowl() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.22, y: 0.12))
        p.addLine(to: CGPoint(x: 0.78, y: 0.12))
        p.addCurve(to: CGPoint(x: 0.50, y: 0.62),
                   control1: CGPoint(x: 0.88, y: 0.30),
                   control2: CGPoint(x: 0.70, y: 0.62))
        p.addCurve(to: CGPoint(x: 0.22, y: 0.12),
                   control1: CGPoint(x: 0.30, y: 0.62),
                   control2: CGPoint(x: 0.12, y: 0.30))
        p.closeSubpath()
        return p
    }

    // MARK: - Flute (thin tall)

    private static func flute() -> Path { fluteBowl() }
    private static func fluteBowl() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.40, y: 0.08))
        p.addLine(to: CGPoint(x: 0.42, y: 0.58))
        p.addQuadCurve(to: CGPoint(x: 0.58, y: 0.58),
                       control: CGPoint(x: 0.50, y: 0.62))
        p.addLine(to: CGPoint(x: 0.60, y: 0.08))
        p.closeSubpath()
        return p
    }

    // MARK: - Shot (small cylinder)

    private static func shot() -> Path {
        var p = Path()
        let left: CGFloat = 0.30
        let right: CGFloat = 0.70
        let top: CGFloat = 0.46
        let bottom: CGFloat = 0.90
        let r: CGFloat = 0.03
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: left, y: bottom - r))
        p.addQuadCurve(to: CGPoint(x: left + r, y: bottom), control: CGPoint(x: left, y: bottom))
        p.addLine(to: CGPoint(x: right - r, y: bottom))
        p.addQuadCurve(to: CGPoint(x: right, y: bottom - r), control: CGPoint(x: right, y: bottom))
        p.addLine(to: CGPoint(x: right, y: top))
        p.closeSubpath()
        return p
    }
    private static func shotBowl() -> Path { shot() }

    // MARK: - Tiki (sculpted)

    private static func tiki() -> Path { tikiBowl() }
    private static func tikiBowl() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.30, y: 0.10))
        p.addLine(to: CGPoint(x: 0.70, y: 0.10))
        p.addCurve(to: CGPoint(x: 0.84, y: 0.50),
                   control1: CGPoint(x: 0.88, y: 0.20),
                   control2: CGPoint(x: 0.94, y: 0.40))
        p.addCurve(to: CGPoint(x: 0.68, y: 0.92),
                   control1: CGPoint(x: 0.78, y: 0.78),
                   control2: CGPoint(x: 0.80, y: 0.92))
        p.addLine(to: CGPoint(x: 0.32, y: 0.92))
        p.addCurve(to: CGPoint(x: 0.16, y: 0.50),
                   control1: CGPoint(x: 0.20, y: 0.92),
                   control2: CGPoint(x: 0.22, y: 0.78))
        p.addCurve(to: CGPoint(x: 0.30, y: 0.10),
                   control1: CGPoint(x: 0.06, y: 0.40),
                   control2: CGPoint(x: 0.12, y: 0.20))
        p.closeSubpath()
        return p
    }
}

// MARK: - Footed-vessel decoration

/// Stem + foot overlay for footed glasses (martini, coupe, wine, flute,
/// snifter, nick & nora, hurricane). Drawn by the preview view on top of the
/// bowl so it composes cleanly regardless of vessel.
struct VesselFooting: View {
    let vessel: Vessel

    private var spec: FootingSpec? {
        switch vessel {
        case .martini:      return .init(stemTop: 0.52, stemWidth: 0.05, footTop: 0.86, footWidth: 0.44)
        case .coupe:        return .init(stemTop: 0.52, stemWidth: 0.05, footTop: 0.86, footWidth: 0.40)
        case .nickAndNora:  return .init(stemTop: 0.58, stemWidth: 0.05, footTop: 0.88, footWidth: 0.40)
        case .wine:         return .init(stemTop: 0.62, stemWidth: 0.05, footTop: 0.90, footWidth: 0.44)
        case .flute:        return .init(stemTop: 0.60, stemWidth: 0.03, footTop: 0.88, footWidth: 0.40)
        case .snifter:      return .init(stemTop: 0.78, stemWidth: 0.10, footTop: 0.92, footWidth: 0.38)
        case .hurricane:    return .init(stemTop: 0.78, stemWidth: 0.10, footTop: 0.92, footWidth: 0.40)
        default:            return nil
        }
    }

    var body: some View {
        if let spec {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    // Stem
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: spec.stemWidth * w,
                               height: (spec.footTop - spec.stemTop) * h)
                        .position(x: w / 2,
                                  y: ((spec.stemTop + spec.footTop) / 2) * h)
                        .overlay(
                            Rectangle()
                                .stroke(.currentVesselStroke, lineWidth: 1.4)
                                .frame(width: spec.stemWidth * w,
                                       height: (spec.footTop - spec.stemTop) * h)
                                .position(x: w / 2,
                                          y: ((spec.stemTop + spec.footTop) / 2) * h)
                        )
                    // Foot (flattened ellipse)
                    Ellipse()
                        .stroke(.currentVesselStroke, lineWidth: 1.4)
                        .frame(width: spec.footWidth * w, height: 0.04 * h)
                        .position(x: w / 2, y: (spec.footTop + 0.02) * h)
                }
            }
        }
    }
}

private struct FootingSpec {
    let stemTop: CGFloat
    let stemWidth: CGFloat
    let footTop: CGFloat
    let footWidth: CGFloat
}

// MARK: - Stroke tint shim

private extension ShapeStyle where Self == Color {
    /// White stroke that reads on the dark previews used in the builder. The
    /// preview view tints this via `.environment(\.colorScheme, .dark)` so
    /// the same shape works against both light and dark backgrounds.
    static var currentVesselStroke: Color { .white.opacity(0.92) }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [.init(.adaptive(minimum: 120))], spacing: 16) {
            ForEach(Vessel.allCases) { v in
                VStack(spacing: 6) {
                    ZStack {
                        VesselShape(vessel: v)
                            .stroke(Color.white, lineWidth: 1.4)
                        VesselFooting(vessel: v)
                    }
                    .frame(width: 110, height: 160)
                    Text(v.display).font(.caption).foregroundStyle(.white)
                }
            }
        }
        .padding()
    }
    .background(Color.black)
}
