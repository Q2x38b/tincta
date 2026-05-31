import SwiftUI

/// Resolves a Garnish enum case into a rendered SwiftUI view. Each garnish is
/// designed to read at small sizes (32–64 pt) as well as floating on the rim
/// of a 200pt drink graphic.
struct GarnishView: View {
    let garnish: Garnish

    var body: some View {
        switch garnish {
        case .cherry:         CherryShape()
        case .olive:          OliveShape()
        case .mintSprig:      MintSprigShape()
        case .rosemary:       RosemaryShape()
        case .cinnamonStick:  CinnamonStickShape()
        case .starAnise:      StarAniseShape()
        case .cucumber:       CucumberShape()
        case .edibleFlower:   EdibleFlowerShape()
        case .sugarRim:       RimDustShape(color: .white)
        case .saltRim:        RimDustShape(color: Color.white.opacity(0.95))
        }
    }
}

struct CherryShape: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Stem
                Path { p in
                    p.move(to: CGPoint(x: s * 0.55, y: s * 0.70))
                    p.addQuadCurve(to: CGPoint(x: s * 0.78, y: s * 0.08),
                                   control: CGPoint(x: s * 0.95, y: s * 0.40))
                }
                .stroke(Color(hex: "#4F2E1A"), lineWidth: max(2, s * 0.05))
                // Cherry body
                Circle()
                    .fill(Color(hex: "#B5263A"))
                    .frame(width: s * 0.62, height: s * 0.62)
                    .position(x: s * 0.45, y: s * 0.70)
                // Highlight
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: s * 0.12, height: s * 0.12)
                    .position(x: s * 0.36, y: s * 0.58)
            }
            .frame(width: s, height: s)
        }
    }
}

struct OliveShape: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Ellipse()
                    .fill(Color(hex: "#6B7B3E"))
                    .frame(width: s * 0.70, height: s * 0.92)
                Circle()
                    .fill(Color(hex: "#C04738"))
                    .frame(width: s * 0.22, height: s * 0.22)
                    .offset(y: -s * 0.30)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

struct MintSprigShape: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Stem
                Path { p in
                    p.move(to: CGPoint(x: s * 0.50, y: s * 0.95))
                    p.addQuadCurve(to: CGPoint(x: s * 0.50, y: s * 0.10),
                                   control: CGPoint(x: s * 0.40, y: s * 0.55))
                }
                .stroke(Color(hex: "#3F6B3A"), lineWidth: max(1.5, s * 0.035))
                // Leaves
                Group {
                    leaf().rotationEffect(.degrees(-35))
                        .position(x: s * 0.30, y: s * 0.30)
                    leaf().rotationEffect(.degrees(35))
                        .position(x: s * 0.70, y: s * 0.38)
                    leaf().rotationEffect(.degrees(-25))
                        .position(x: s * 0.32, y: s * 0.60)
                    leaf().rotationEffect(.degrees(25))
                        .position(x: s * 0.68, y: s * 0.66)
                }
                .frame(width: s * 0.42, height: s * 0.30)
            }
        }
    }

    private func leaf() -> some View {
        LeafShape()
            .fill(LinearGradient(
                colors: [Color(hex: "#79B25A"), Color(hex: "#4F8A45")],
                startPoint: .top, endPoint: .bottom))
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.midY))
        return p
    }
}

struct RosemaryShape: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: s * 0.50, y: s * 0.95))
                    p.addLine(to: CGPoint(x: s * 0.50, y: s * 0.05))
                }
                .stroke(Color(hex: "#5C6E48"), lineWidth: max(1.2, s * 0.025))
                ForEach(0..<6) { i in
                    let y = s * (0.18 + Double(i) * 0.13)
                    Capsule()
                        .fill(Color(hex: "#779863"))
                        .frame(width: s * 0.04, height: s * 0.18)
                        .rotationEffect(.degrees(-32))
                        .position(x: s * 0.40, y: y)
                    Capsule()
                        .fill(Color(hex: "#779863"))
                        .frame(width: s * 0.04, height: s * 0.18)
                        .rotationEffect(.degrees(32))
                        .position(x: s * 0.60, y: y + s * 0.04)
                }
            }
        }
    }
}

struct CinnamonStickShape: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            RoundedRectangle(cornerRadius: s * 0.06)
                .fill(LinearGradient(
                    colors: [Color(hex: "#7B4324"), Color(hex: "#A35A30")],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: s * 0.30, height: s * 0.92)
                .overlay(
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule().fill(Color.black.opacity(0.15))
                                .frame(width: s * 0.02)
                        }
                    }
                )
                .rotationEffect(.degrees(-12))
                .position(x: s / 2, y: s / 2)
        }
    }
}

struct StarAniseShape: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<8) { i in
                    Capsule()
                        .fill(Color(hex: "#7E4527"))
                        .frame(width: s * 0.16, height: s * 0.50)
                        .offset(y: -s * 0.18)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
                Circle()
                    .fill(Color(hex: "#5A2E18"))
                    .frame(width: s * 0.22, height: s * 0.22)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

struct CucumberShape: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Ellipse()
                    .fill(Color(hex: "#7CA86A"))
                    .frame(width: s * 0.94, height: s * 0.34)
                Ellipse()
                    .fill(Color(hex: "#C7DCAE"))
                    .frame(width: s * 0.82, height: s * 0.22)
                // Seeds
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(Color(hex: "#A8C683"))
                        .frame(width: s * 0.06, height: s * 0.10)
                        .offset(x: CGFloat(i - 1) * s * 0.18)
                }
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

struct EdibleFlowerShape: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<6) { i in
                    Ellipse()
                        .fill(Color(hex: "#E6A6BC"))
                        .frame(width: s * 0.30, height: s * 0.50)
                        .offset(y: -s * 0.18)
                        .rotationEffect(.degrees(Double(i) * 60))
                }
                Circle()
                    .fill(Color(hex: "#E9C76A"))
                    .frame(width: s * 0.22, height: s * 0.22)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

/// A thin band of dust along the top edge — used for sugar / salt rims.
struct RimDustShape: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                var rng = SeededRNG(seed: 0xBADA55)
                let count = 80
                for _ in 0..<count {
                    let x = Double.random(in: 0...1, using: &rng) * size.width
                    let y = Double.random(in: 0...1, using: &rng) * size.height * 0.4
                    let r = 1.0 + Double.random(in: 0...1, using: &rng) * 2.0
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [.init(.adaptive(minimum: 80))], spacing: 16) {
            ForEach(Garnish.allCases) { g in
                VStack(spacing: 6) {
                    GarnishView(garnish: g)
                        .frame(width: 64, height: 64)
                        .background(Color.gray.opacity(0.1))
                    Text(g.display).font(.caption2)
                }
            }
        }
        .padding()
    }
}
