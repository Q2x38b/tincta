import SwiftUI

/// Floating circular button rendered with iOS 26 Liquid Glass. Used for the
/// menu button (top-right) and the create button (bottom-right) on the Library.
struct GlassButton: View {
    let systemImage: String
    let action: () -> Void
    /// Override the default 56pt diameter (e.g. for inline glass chips).
    let diameter: CGFloat
    let tint: Color

    init(
        systemImage: String,
        diameter: CGFloat = 56,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.diameter = diameter
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.42, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: diameter, height: diameter)
                .glassEffect(.regular.interactive(), in: Circle())
                .shadow(color: Color.tinctaShadow, radius: 14, x: 0, y: 6)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .frame(minWidth: 44, minHeight: 44)
    }
}

/// Container that lets multiple glass surfaces "morph" together as a single
/// Liquid Glass element when their bounds intersect.
struct TinctaGlassContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    var body: some View {
        GlassEffectContainer { content() }
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.tinctaInk, Color(hex: "#3A3640")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        VStack(spacing: 24) {
            GlassButton(systemImage: "ellipsis") {}
            GlassButton(systemImage: "plus") {}
        }
    }
}
