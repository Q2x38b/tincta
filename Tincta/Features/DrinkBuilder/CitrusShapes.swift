import SwiftUI

/// Lightweight color constants for citrus rinds & flesh.
enum CitrusColor {
    static let lemonRind   = Color(hex: "#E8C547")
    static let lemonFlesh  = Color(hex: "#F4E07A")
    static let limeRind    = Color(hex: "#7DB341")
    static let limeFlesh   = Color(hex: "#C1DC8A")
    static let orangeRind  = Color(hex: "#E27F2A")
    static let orangeFlesh = Color(hex: "#F3B25E")
    static let grapefruitRind  = Color(hex: "#C95643")
    static let grapefruitFlesh = Color(hex: "#E89A82")
    static let pith = Color.white.opacity(0.85)
}

/// Resolves a single Citrus enum case into a rendered SwiftUI view positioned
/// over the drink — wheels float on top of the liquid, wedges sit on the rim,
/// twists drape over the rim, peels are slender strips.
struct CitrusView: View {
    let citrus: Citrus

    var body: some View {
        switch citrus {
        case .lemonWheel:      WheelShape(rind: CitrusColor.lemonRind, flesh: CitrusColor.lemonFlesh)
        case .limeWheel:       WheelShape(rind: CitrusColor.limeRind, flesh: CitrusColor.limeFlesh)
        case .orangeWheel:     WheelShape(rind: CitrusColor.orangeRind, flesh: CitrusColor.orangeFlesh)
        case .lemonWedge:      WedgeShape(rind: CitrusColor.lemonRind, flesh: CitrusColor.lemonFlesh)
        case .limeWedge:       WedgeShape(rind: CitrusColor.limeRind, flesh: CitrusColor.limeFlesh)
        case .lemonTwist:      TwistShape(rind: CitrusColor.lemonRind)
        case .limeTwist:       TwistShape(rind: CitrusColor.limeRind)
        case .orangeTwist:     TwistShape(rind: CitrusColor.orangeRind)
        case .lemonPeel:       PeelShape(rind: CitrusColor.lemonRind)
        case .orangePeel:      PeelShape(rind: CitrusColor.orangeRind)
        case .grapefruitPeel:  PeelShape(rind: CitrusColor.grapefruitRind)
        }
    }
}

/// Citrus wheel — a disc of flesh with rind ring and faint segments.
struct WheelShape: View {
    let rind: Color
    let flesh: Color

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(rind)
                Circle().fill(CitrusColor.pith).padding(size * 0.06)
                Circle().fill(flesh).padding(size * 0.12)
                // Segments
                ForEach(0..<8) { i in
                    Rectangle()
                        .fill(CitrusColor.pith.opacity(0.7))
                        .frame(width: 1, height: size * 0.36)
                        .offset(y: -size * 0.18)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
                Circle().fill(CitrusColor.pith).frame(width: size * 0.08, height: size * 0.08)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

/// Wedge of citrus — quarter-circle slice.
struct WedgeShape: View {
    let rind: Color
    let flesh: Color

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                WedgePath()
                    .fill(rind)
                WedgePath()
                    .inset(by: s * 0.08)
                    .fill(flesh)
            }
            .frame(width: s, height: s)
        }
    }
}

private struct WedgePath: Shape {
    var inset: CGFloat = 0
    func inset(by amount: CGFloat) -> WedgePath {
        var copy = self; copy.inset += amount; return copy
    }
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX, y: r.maxY),
                 radius: r.width,
                 startAngle: .degrees(0),
                 endAngle: .degrees(-90),
                 clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// Curly twist — a thin spiraling strip of rind.
struct TwistShape: View {
    let rind: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: w * 0.20, y: h * 0.10))
                p.addCurve(to: CGPoint(x: w * 0.80, y: h * 0.50),
                           control1: CGPoint(x: w * 0.10, y: h * 0.40),
                           control2: CGPoint(x: w * 0.95, y: h * 0.20))
                p.addCurve(to: CGPoint(x: w * 0.30, y: h * 0.92),
                           control1: CGPoint(x: w * 0.70, y: h * 0.78),
                           control2: CGPoint(x: w * 0.10, y: h * 0.70))
            }
            .stroke(rind, style: StrokeStyle(lineWidth: max(3, w * 0.10), lineCap: .round))
        }
    }
}

/// Straight peel strip — a wider, less curly rind sliver.
struct PeelShape: View {
    let rind: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: w * 0.20, y: h * 0.10))
                p.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.90),
                               control: CGPoint(x: w * 0.30, y: h * 0.80))
            }
            .stroke(rind, style: StrokeStyle(lineWidth: max(5, w * 0.16), lineCap: .round))
        }
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [.init(.adaptive(minimum: 80))], spacing: 16) {
            ForEach(Citrus.allCases) { c in
                VStack(spacing: 6) {
                    CitrusView(citrus: c)
                        .frame(width: 64, height: 64)
                    Text(c.display).font(.caption2)
                }
            }
        }
        .padding()
    }
}
