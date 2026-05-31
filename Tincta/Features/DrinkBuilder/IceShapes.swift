import SwiftUI

/// One large cube floating in the upper portion of the liquid.
struct HugeIceShape: Shape {
    func path(in rect: CGRect) -> Path {
        // A square with subtle perspective, centered horizontally.
        let size = min(rect.width, rect.height) * 0.55
        let x = rect.midX - size / 2
        let y = rect.midY - size / 2
        let cube = CGRect(x: x, y: y, width: size, height: size)
        var p = Path(roundedRect: cube, cornerRadius: size * 0.10)
        // Tilt highlight diagonal
        p.move(to: CGPoint(x: cube.minX + size * 0.18, y: cube.minY + size * 0.18))
        p.addLine(to: CGPoint(x: cube.minX + size * 0.42, y: cube.minY + size * 0.42))
        return p
    }
}

/// Three smaller cubes scattered.
struct IceCubesShape: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) * 0.28
            ZStack {
                cube
                    .frame(width: s, height: s)
                    .position(x: geo.size.width * 0.36, y: geo.size.height * 0.42)
                    .rotationEffect(.degrees(-8))
                cube
                    .frame(width: s * 0.95, height: s * 0.95)
                    .position(x: geo.size.width * 0.62, y: geo.size.height * 0.36)
                    .rotationEffect(.degrees(12))
                cube
                    .frame(width: s * 1.05, height: s * 1.05)
                    .position(x: geo.size.width * 0.50, y: geo.size.height * 0.62)
                    .rotationEffect(.degrees(4))
            }
        }
    }

    private var cube: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white.opacity(0.95), lineWidth: 1)
            )
    }
}

/// Crushed-ice stipple — a cloud of tiny chips packed into a region.
struct CrushedIceShape: View {
    var body: some View {
        Canvas { ctx, size in
            // Deterministic pseudo-random scatter of chips.
            var rng = SystemRNG(seed: 0xC0_FF_EE)
            let count = 70
            for _ in 0..<count {
                let x = Double.random(in: 0...1, using: &rng) * size.width
                // Keep chips in the upper 60% of the box (above ice line)
                let y = (0.05 + Double.random(in: 0...1, using: &rng) * 0.7) * size.height
                let w = 4 + Double.random(in: 0...1, using: &rng) * 6
                let h = 3 + Double.random(in: 0...1, using: &rng) * 5
                let rect = CGRect(x: x - w/2, y: y - h/2, width: w, height: h)
                let path = Path(roundedRect: rect, cornerRadius: 1.5)
                ctx.fill(path, with: .color(.white.opacity(0.9)))
            }
        }
    }
}

/// Tiny seeded RNG so the crushed-ice scatter is stable across redraws.
struct SystemRNG: RandomNumberGenerator {
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

/// Switches between the ice variants and positions them inside the given rect.
struct IceLayerView: View {
    let ice: IceType?

    var body: some View {
        switch ice {
        case .huge:
            HugeIceShape()
                .fill(Color.white.opacity(0.55))
                .overlay(
                    HugeIceShape()
                        .stroke(Color.white.opacity(0.85), lineWidth: 1)
                )
        case .cubes:
            IceCubesShape()
        case .crushed:
            CrushedIceShape()
        case .none, .some(.none):
            EmptyView()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach(IceType.allCases) { ice in
            ZStack {
                Rectangle().fill(Color(hex: "#C8843B"))
                IceLayerView(ice: ice)
            }
            .frame(width: 220, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(Text(ice.display).font(.caption).foregroundStyle(.white), alignment: .bottom)
        }
    }
    .padding()
}
