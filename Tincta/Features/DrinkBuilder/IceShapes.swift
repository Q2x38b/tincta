import SwiftUI

/// Switches between the ice variants and lays them out inside the given rect.
/// Each variant uses a translucent fill + crisp stroked outline + a separate
/// specular highlight overlay so the geometry stays clean — the old shape
/// included the highlight as part of the path which made the fill weave
/// through the diagonal and read as a hexagonal block.
struct IceLayerView: View {
    let ice: IceType?

    var body: some View {
        switch ice {
        case .huge:
            HugeIceView()
        case .cubes:
            IceCubesView()
        case .crushed:
            CrushedIceView()
        case .none, .some(.none):
            EmptyView()
        }
    }
}

// MARK: - One large rocks cube

/// The classic Old-Fashioned ice rock: a translucent cube with rounded edges,
/// a crisp white rim, and a couple of specular highlights so it reads as
/// real ice rather than a flat block.
struct HugeIceView: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.62
            let rect = CGRect(
                x: (geo.size.width - side) / 2,
                y: (geo.size.height - side) / 2 + geo.size.height * 0.05,
                width: side,
                height: side
            )
            let cube = RoundedRectangle(cornerRadius: side * 0.08, style: .continuous)
                .path(in: rect)

            ZStack {
                // Translucent body so the liquid colour shows through.
                cube.fill(Color.white.opacity(0.32))

                // Soft inner glow from the upper-left so the cube has depth.
                cube
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55),
                                     Color.white.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Crisp rim.
                cube.stroke(Color.white.opacity(0.85), lineWidth: 1.4)

                // Two specular highlights — one short on the top edge, one
                // longer along the upper-left face.
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: side * 0.30, height: side * 0.05)
                    .position(x: rect.minX + side * 0.30, y: rect.minY + side * 0.18)
                    .rotationEffect(.degrees(-6), anchor: .center)

                Capsule()
                    .fill(Color.white.opacity(0.72))
                    .frame(width: side * 0.05, height: side * 0.45)
                    .position(x: rect.minX + side * 0.18, y: rect.minY + side * 0.45)
            }
        }
    }
}

// MARK: - Three loose cubes

struct IceCubesView: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) * 0.30
            ZStack {
                cube(size: s)
                    .position(x: geo.size.width * 0.36, y: geo.size.height * 0.44)
                    .rotationEffect(.degrees(-10))
                cube(size: s * 0.92)
                    .position(x: geo.size.width * 0.62, y: geo.size.height * 0.38)
                    .rotationEffect(.degrees(14))
                cube(size: s * 1.04)
                    .position(x: geo.size.width * 0.50, y: geo.size.height * 0.66)
                    .rotationEffect(.degrees(4))
            }
        }
    }

    private func cube(size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        return shape
            .fill(Color.white.opacity(0.55))
            .overlay(shape.stroke(Color.white.opacity(0.92), lineWidth: 1))
            .overlay(
                // Single crisp highlight per cube.
                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: size * 0.30, height: size * 0.06)
                    .offset(x: -size * 0.12, y: -size * 0.30)
            )
            .frame(width: size, height: size)
    }
}

// MARK: - Crushed ice (stippled cloud)

struct CrushedIceView: View {
    var body: some View {
        Canvas { ctx, size in
            // Deterministic pseudo-random scatter so it doesn't flicker on
            // every redraw.
            var rng = SeededRNG(seed: 0xC0_FF_EE)
            let count = 80
            for _ in 0..<count {
                let x = Double.random(in: 0...1, using: &rng) * size.width
                // Pack the chips into the upper 65% of the box (above ice line).
                let y = (0.05 + Double.random(in: 0...1, using: &rng) * 0.70) * size.height
                let w = 5 + Double.random(in: 0...1, using: &rng) * 7
                let h = 4 + Double.random(in: 0...1, using: &rng) * 6
                let rect = CGRect(x: x - w/2, y: y - h/2, width: w, height: h)
                let path = Path(roundedRect: rect, cornerRadius: 1.6)
                ctx.fill(path, with: .color(.white.opacity(0.9)))
                ctx.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 0.4)
            }
        }
    }
}

// MARK: - Stable RNG so the stipple doesn't shimmer

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed != 0 ? seed : 0xDEADBEEF }
    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach(IceType.allCases) { ice in
            ZStack {
                Rectangle().fill(Color(hex: "#C8843B"))
                IceLayerView(ice: ice)
            }
            .frame(width: 240, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                Text(ice.display).font(.caption).foregroundStyle(.white).padding(6),
                alignment: .bottom
            )
        }
    }
    .padding()
}
