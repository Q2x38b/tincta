import SwiftUI

/// Canonical placement tokens for Tincta's floating chrome. The menu button
/// pins to the top-trailing safe-area corner; the create button pins to the
/// bottom-trailing safe-area corner. These insets match the spec and stay
/// consistent across Library, Recipe Detail, and Settings.
public enum TinctaFloatingChrome {
    public static let edgeInset: CGFloat = 20
    public static let topInset: CGFloat = 12
    public static let bottomInset: CGFloat = 28
}

/// Overlay modifier that positions the menu (top-right) and create
/// (bottom-right) glass buttons over a screen, respecting safe areas.
///
/// Either button may be `nil` (e.g. on screens that only need a menu).
public struct FloatingButtonsOverlay: ViewModifier {
    let menu: GlassButton?
    let create: GlassButton?

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if let menu {
                    menu
                        .padding(.trailing, TinctaFloatingChrome.edgeInset)
                        .padding(.top, TinctaFloatingChrome.topInset)
                        .accessibilityLabel("Menu")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let create {
                    create
                        .padding(.trailing, TinctaFloatingChrome.edgeInset)
                        .padding(.bottom, TinctaFloatingChrome.bottomInset)
                        .accessibilityLabel("New recipe")
                }
            }
    }
}

public extension View {
    /// Pin a menu button (top-trailing) and create button (bottom-trailing)
    /// over the receiver. Pass `nil` to suppress either slot.
    func tinctaFloatingButtons(
        menu: GlassButton? = nil,
        create: GlassButton? = nil
    ) -> some View {
        modifier(FloatingButtonsOverlay(menu: menu, create: create))
    }
}

#Preview("Floating chrome over a card") {
    ZStack {
        LinearGradient(colors: [Color(hex: "#C9A36A"), Color(hex: "#7A4A2B")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
    .tinctaFloatingButtons(
        menu: GlassButton(systemImage: "ellipsis") {},
        create: GlassButton(systemImage: "plus") {}
    )
}
