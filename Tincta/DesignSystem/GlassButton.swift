import SwiftUI

/// Floating circular button rendered with iOS 18 Liquid Glass on supported
/// devices and `.ultraThinMaterial` on older runtime versions. Used for the
/// menu button (top-right) and the create button (bottom-right) on the Library.
public struct GlassButton: View {
    let systemImage: String
    let action: () -> Void
    /// Override the default 56pt diameter (e.g. for inline glass chips).
    let diameter: CGFloat
    let tint: Color

    public init(
        systemImage: String,
        diameter: CGFloat = 56,
        tint: Color = .white,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.diameter = diameter
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.42, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: diameter, height: diameter)
                .background(background)
                .overlay(
                    Circle()
                        .strokeBorder(Color.tinctaGlassStroke, lineWidth: 0.7)
                )
                .shadow(color: Color.tinctaShadow, radius: 14, x: 0, y: 6)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .frame(minWidth: 44, minHeight: 44)
    }

    @ViewBuilder
    private var background: some View {
        if #available(iOS 26, *) {
            // Liquid Glass on iOS 26 (where `.glassEffect` is available).
            Circle()
                .fill(.clear)
                .glassEffect(.regular, in: Circle())
        } else if #available(iOS 18, *) {
            // iOS 18: best-available material.
            Circle()
                .fill(.ultraThinMaterial)
        } else {
            Circle()
                .fill(.ultraThinMaterial)
        }
    }
}

/// Container that lets multiple glass surfaces "morph" together when supported.
/// On unsupported runtimes it's a transparent passthrough.
public struct TinctaGlassContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    public var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer { content() }
        } else {
            content()
        }
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
