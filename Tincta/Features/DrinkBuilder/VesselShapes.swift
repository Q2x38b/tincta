import SwiftUI

/// Iconic silhouette of a barware vessel, drawn as a pure SwiftUI `Shape`.
/// The path is described in a normalized 1×1 coordinate space and scaled to the
/// drawing rect. Heights and widths roughly match the silhouette family used in
/// design Image 5 — stubby for rocks, tall for collins, balloon for snifter, etc.
struct VesselShape: Shape {
    let vessel: Vessel

    func path(in rect: CGRect) -> Path {
        let p = normalizedPath()
        // Scale the normalized 0..1 path into the rect, preserving aspect by
        // letting the caller decide aspect. Most callers give us a roughly
        // 1:1.4 portrait box.
        let t = CGAffineTransform(scaleX: rect.width, y: rect.height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return p.applying(t)
    }

    /// Returns the vessel outline only. Used both for stroking and for clipping
    /// the liquid layer.
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

    /// Slightly-inset outline of the vessel, used as a clip for the liquid
    /// layer. Returned in the same normalized 0..1 space.
    func liquidPath() -> Path {
        var outline = normalizedPath()
        let bounds = outline.boundingRect
        let inset = CGAffineTransform(scaleX: 0.92, y: 0.96)
            .concatenating(CGAffineTransform(
                translationX: bounds.midX * (1 - 0.92),
                y: bounds.maxY * (1 - 0.96)
            ))
        outline = outline.applying(inset)
        return outline
    }

    // MARK: - Individual vessels (normalized 0..1 paths)

    private static func rocks() -> Path {
        // Stubby cylinder, wider than tall. Bowl from y=0.18 to 0.95, body
        // sits centered.
        var p = Path()
        let left: CGFloat = 0.12
        let right: CGFloat = 0.88
        let top: CGFloat = 0.18
        let bottom: CGFloat = 0.92
        let cornerR: CGFloat = 0.04
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: left, y: bottom - cornerR))
        p.addQuadCurve(to: CGPoint(x: left + cornerR, y: bottom),
                       control: CGPoint(x: left, y: bottom))
        p.addLine(to: CGPoint(x: right - cornerR, y: bottom))
        p.addQuadCurve(to: CGPoint(x: right, y: bottom - cornerR),
                       control: CGPoint(x: right, y: bottom))
        p.addLine(to: CGPoint(x: right, y: top))
        // Rim ellipse hint.
        p.addQuadCurve(to: CGPoint(x: left, y: top),
                       control: CGPoint(x: 0.5, y: top - 0.05))
        return p
    }

    private static func collins() -> Path {
        // Tall narrow cylinder.
        var p = Path()
        let left: CGFloat = 0.30
        let right: CGFloat = 0.70
        let top: CGFloat = 0.06
        let bottom: CGFloat = 0.94
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: left, y: bottom - 0.03))
        p.addQuadCurve(to: CGPoint(x: left + 0.03, y: bottom),
                       control: CGPoint(x: left, y: bottom))
        p.addLine(to: CGPoint(x: right - 0.03, y: bottom))
        p.addQuadCurve(to: CGPoint(x: right, y: bottom - 0.03),
                       control: CGPoint(x: right, y: bottom))
        p.addLine(to: CGPoint(x: right, y: top))
        p.addQuadCurve(to: CGPoint(x: left, y: top),
                       control: CGPoint(x: 0.5, y: top - 0.04))
        return p
    }

    private static func highball() -> Path {
        // Medium-tall cylinder, slight outward taper.
        var p = Path()
        let topLeft: CGFloat = 0.24
        let topRight: CGFloat = 0.76
        let botLeft: CGFloat = 0.28
        let botRight: CGFloat = 0.72
        let top: CGFloat = 0.10
        let bottom: CGFloat = 0.93
        p.move(to: CGPoint(x: topLeft, y: top))
        p.addLine(to: CGPoint(x: botLeft, y: bottom - 0.03))
        p.addQuadCurve(to: CGPoint(x: botLeft + 0.03, y: bottom),
                       control: CGPoint(x: botLeft, y: bottom))
        p.addLine(to: CGPoint(x: botRight - 0.03, y: bottom))
        p.addQuadCurve(to: CGPoint(x: botRight, y: bottom - 0.03),
                       control: CGPoint(x: botRight, y: bottom))
        p.addLine(to: CGPoint(x: topRight, y: top))
        p.addQuadCurve(to: CGPoint(x: topLeft, y: top),
                       control: CGPoint(x: 0.5, y: top - 0.04))
        return p
    }

    private static func snifter() -> Path {
        // Balloon bowl on a tiny stem.
        var p = Path()
        // Stem base
        let stemBase = CGRect(x: 0.40, y: 0.92, width: 0.20, height: 0.05)
        let stem = CGRect(x: 0.46, y: 0.78, width: 0.08, height: 0.16)
        // Balloon bowl
        p.move(to: CGPoint(x: 0.32, y: 0.18))    // rim left
        p.addQuadCurve(to: CGPoint(x: 0.08, y: 0.50),
                       control: CGPoint(x: 0.04, y: 0.22))
        p.addQuadCurve(to: CGPoint(x: 0.30, y: 0.80),
                       control: CGPoint(x: 0.06, y: 0.82))
        p.addLine(to: CGPoint(x: 0.46, y: 0.80))
        p.addRect(stem)
        p.addRect(stemBase)
        p.move(to: CGPoint(x: 0.54, y: 0.80))
        p.addQuadCurve(to: CGPoint(x: 0.70, y: 0.80),
                       control: CGPoint(x: 0.62, y: 0.82))
        p.addQuadCurve(to: CGPoint(x: 0.92, y: 0.50),
                       control: CGPoint(x: 0.94, y: 0.82))
        p.addQuadCurve(to: CGPoint(x: 0.68, y: 0.18),
                       control: CGPoint(x: 0.96, y: 0.22))
        // rim
        p.addQuadCurve(to: CGPoint(x: 0.32, y: 0.18),
                       control: CGPoint(x: 0.50, y: 0.14))
        return p
    }

    private static func coupe() -> Path {
        // Wide shallow bowl on a slim stem with foot.
        var p = Path()
        // Bowl (shallow half-ellipse)
        p.move(to: CGPoint(x: 0.10, y: 0.18))
        p.addQuadCurve(to: CGPoint(x: 0.90, y: 0.18),
                       control: CGPoint(x: 0.50, y: 0.12))
        p.addQuadCurve(to: CGPoint(x: 0.50, y: 0.52),
                       control: CGPoint(x: 0.90, y: 0.50))
        p.addQuadCurve(to: CGPoint(x: 0.10, y: 0.18),
                       control: CGPoint(x: 0.10, y: 0.50))
        // Stem
        p.addRect(CGRect(x: 0.475, y: 0.50, width: 0.05, height: 0.36))
        // Foot
        p.move(to: CGPoint(x: 0.30, y: 0.88))
        p.addQuadCurve(to: CGPoint(x: 0.70, y: 0.88),
                       control: CGPoint(x: 0.50, y: 0.84))
        p.addQuadCurve(to: CGPoint(x: 0.30, y: 0.88),
                       control: CGPoint(x: 0.50, y: 0.94))
        return p
    }

    private static func martini() -> Path {
        // V-cone bowl on a stem.
        var p = Path()
        p.move(to: CGPoint(x: 0.10, y: 0.10))
        p.addLine(to: CGPoint(x: 0.90, y: 0.10))
        p.addLine(to: CGPoint(x: 0.50, y: 0.52))
        p.closeSubpath()
        // Stem
        p.addRect(CGRect(x: 0.475, y: 0.52, width: 0.05, height: 0.34))
        // Foot
        p.move(to: CGPoint(x: 0.28, y: 0.88))
        p.addQuadCurve(to: CGPoint(x: 0.72, y: 0.88),
                       control: CGPoint(x: 0.50, y: 0.84))
        p.addQuadCurve(to: CGPoint(x: 0.28, y: 0.88),
                       control: CGPoint(x: 0.50, y: 0.94))
        return p
    }

    private static func nickAndNora() -> Path {
        // Small coupe-ish bowl, slightly deeper.
        var p = Path()
        p.move(to: CGPoint(x: 0.22, y: 0.20))
        p.addQuadCurve(to: CGPoint(x: 0.78, y: 0.20),
                       control: CGPoint(x: 0.50, y: 0.14))
        p.addQuadCurve(to: CGPoint(x: 0.50, y: 0.58),
                       control: CGPoint(x: 0.84, y: 0.56))
        p.addQuadCurve(to: CGPoint(x: 0.22, y: 0.20),
                       control: CGPoint(x: 0.16, y: 0.56))
        // Stem
        p.addRect(CGRect(x: 0.475, y: 0.56, width: 0.05, height: 0.30))
        // Foot
        p.move(to: CGPoint(x: 0.30, y: 0.88))
        p.addQuadCurve(to: CGPoint(x: 0.70, y: 0.88),
                       control: CGPoint(x: 0.50, y: 0.84))
        p.addQuadCurve(to: CGPoint(x: 0.30, y: 0.88),
                       control: CGPoint(x: 0.50, y: 0.94))
        return p
    }

    private static func hurricane() -> Path {
        // Curvy tulip on a short stem.
        var p = Path()
        p.move(to: CGPoint(x: 0.22, y: 0.08))
        // Right side first to ensure clockwise.
        p.addQuadCurve(to: CGPoint(x: 0.20, y: 0.50),
                       control: CGPoint(x: 0.00, y: 0.30))
        p.addQuadCurve(to: CGPoint(x: 0.32, y: 0.78),
                       control: CGPoint(x: 0.36, y: 0.66))
        p.addLine(to: CGPoint(x: 0.68, y: 0.78))
        p.addQuadCurve(to: CGPoint(x: 0.80, y: 0.50),
                       control: CGPoint(x: 0.64, y: 0.66))
        p.addQuadCurve(to: CGPoint(x: 0.78, y: 0.08),
                       control: CGPoint(x: 1.00, y: 0.30))
        p.addQuadCurve(to: CGPoint(x: 0.22, y: 0.08),
                       control: CGPoint(x: 0.50, y: 0.04))
        // Short stem + foot
        p.addRect(CGRect(x: 0.45, y: 0.78, width: 0.10, height: 0.10))
        p.move(to: CGPoint(x: 0.30, y: 0.92))
        p.addQuadCurve(to: CGPoint(x: 0.70, y: 0.92),
                       control: CGPoint(x: 0.50, y: 0.86))
        p.addQuadCurve(to: CGPoint(x: 0.30, y: 0.92),
                       control: CGPoint(x: 0.50, y: 0.96))
        return p
    }

    private static func copperMug() -> Path {
        // Mug with a handle on the right.
        var p = Path()
        p.move(to: CGPoint(x: 0.18, y: 0.16))
        p.addLine(to: CGPoint(x: 0.18, y: 0.88))
        p.addQuadCurve(to: CGPoint(x: 0.24, y: 0.92),
                       control: CGPoint(x: 0.18, y: 0.92))
        p.addLine(to: CGPoint(x: 0.66, y: 0.92))
        p.addQuadCurve(to: CGPoint(x: 0.72, y: 0.88),
                       control: CGPoint(x: 0.72, y: 0.92))
        p.addLine(to: CGPoint(x: 0.72, y: 0.16))
        p.addQuadCurve(to: CGPoint(x: 0.18, y: 0.16),
                       control: CGPoint(x: 0.45, y: 0.12))
        // Handle (D-shape)
        p.move(to: CGPoint(x: 0.72, y: 0.36))
        p.addQuadCurve(to: CGPoint(x: 0.72, y: 0.74),
                       control: CGPoint(x: 0.98, y: 0.55))
        p.addLine(to: CGPoint(x: 0.78, y: 0.70))
        p.addQuadCurve(to: CGPoint(x: 0.78, y: 0.40),
                       control: CGPoint(x: 0.92, y: 0.55))
        p.closeSubpath()
        return p
    }

    private static func wine() -> Path {
        // Tulip wine glass.
        var p = Path()
        p.move(to: CGPoint(x: 0.22, y: 0.12))
        p.addQuadCurve(to: CGPoint(x: 0.78, y: 0.12),
                       control: CGPoint(x: 0.50, y: 0.06))
        p.addQuadCurve(to: CGPoint(x: 0.74, y: 0.54),
                       control: CGPoint(x: 0.86, y: 0.34))
        p.addQuadCurve(to: CGPoint(x: 0.50, y: 0.62),
                       control: CGPoint(x: 0.68, y: 0.62))
        p.addQuadCurve(to: CGPoint(x: 0.26, y: 0.54),
                       control: CGPoint(x: 0.32, y: 0.62))
        p.addQuadCurve(to: CGPoint(x: 0.22, y: 0.12),
                       control: CGPoint(x: 0.14, y: 0.34))
        // Stem & foot
        p.addRect(CGRect(x: 0.475, y: 0.62, width: 0.05, height: 0.26))
        p.move(to: CGPoint(x: 0.28, y: 0.90))
        p.addQuadCurve(to: CGPoint(x: 0.72, y: 0.90),
                       control: CGPoint(x: 0.50, y: 0.86))
        p.addQuadCurve(to: CGPoint(x: 0.28, y: 0.90),
                       control: CGPoint(x: 0.50, y: 0.96))
        return p
    }

    private static func flute() -> Path {
        // Thin tall champagne flute.
        var p = Path()
        p.move(to: CGPoint(x: 0.40, y: 0.08))
        p.addLine(to: CGPoint(x: 0.42, y: 0.58))
        p.addQuadCurve(to: CGPoint(x: 0.58, y: 0.58),
                       control: CGPoint(x: 0.50, y: 0.64))
        p.addLine(to: CGPoint(x: 0.60, y: 0.08))
        p.addQuadCurve(to: CGPoint(x: 0.40, y: 0.08),
                       control: CGPoint(x: 0.50, y: 0.04))
        // Stem & foot
        p.addRect(CGRect(x: 0.485, y: 0.58, width: 0.03, height: 0.28))
        p.move(to: CGPoint(x: 0.30, y: 0.88))
        p.addQuadCurve(to: CGPoint(x: 0.70, y: 0.88),
                       control: CGPoint(x: 0.50, y: 0.84))
        p.addQuadCurve(to: CGPoint(x: 0.30, y: 0.88),
                       control: CGPoint(x: 0.50, y: 0.94))
        return p
    }

    private static func shot() -> Path {
        // Small cylinder.
        var p = Path()
        let left: CGFloat = 0.30
        let right: CGFloat = 0.70
        let top: CGFloat = 0.46
        let bottom: CGFloat = 0.90
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: left, y: bottom - 0.03))
        p.addQuadCurve(to: CGPoint(x: left + 0.03, y: bottom),
                       control: CGPoint(x: left, y: bottom))
        p.addLine(to: CGPoint(x: right - 0.03, y: bottom))
        p.addQuadCurve(to: CGPoint(x: right, y: bottom - 0.03),
                       control: CGPoint(x: right, y: bottom))
        p.addLine(to: CGPoint(x: right, y: top))
        p.addQuadCurve(to: CGPoint(x: left, y: top),
                       control: CGPoint(x: 0.5, y: top - 0.05))
        return p
    }

    private static func tiki() -> Path {
        // Sculpted tiki mug — wider middle, tapered top and bottom.
        var p = Path()
        p.move(to: CGPoint(x: 0.30, y: 0.10))
        p.addQuadCurve(to: CGPoint(x: 0.16, y: 0.40),
                       control: CGPoint(x: 0.10, y: 0.18))
        p.addQuadCurve(to: CGPoint(x: 0.16, y: 0.70),
                       control: CGPoint(x: 0.06, y: 0.55))
        p.addQuadCurve(to: CGPoint(x: 0.32, y: 0.92),
                       control: CGPoint(x: 0.20, y: 0.92))
        p.addLine(to: CGPoint(x: 0.68, y: 0.92))
        p.addQuadCurve(to: CGPoint(x: 0.84, y: 0.70),
                       control: CGPoint(x: 0.80, y: 0.92))
        p.addQuadCurve(to: CGPoint(x: 0.84, y: 0.40),
                       control: CGPoint(x: 0.94, y: 0.55))
        p.addQuadCurve(to: CGPoint(x: 0.70, y: 0.10),
                       control: CGPoint(x: 0.90, y: 0.18))
        p.addQuadCurve(to: CGPoint(x: 0.30, y: 0.10),
                       control: CGPoint(x: 0.50, y: 0.06))
        return p
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [.init(.adaptive(minimum: 100))], spacing: 16) {
            ForEach(Vessel.allCases) { v in
                VStack(spacing: 6) {
                    VesselShape(vessel: v)
                        .stroke(Color.black, lineWidth: 1.2)
                        .frame(width: 100, height: 140)
                    Text(v.display).font(.caption)
                }
            }
        }
        .padding()
    }
}
