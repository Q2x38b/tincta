import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Lightweight haptic feedback helper. Centralised here so every floating
/// chrome surface fires the same crisp tap impulse.
public enum TinctaHaptics {
    public static func tap() {
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
        #endif
    }

    public static func selection() {
        #if canImport(UIKit)
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
        #endif
    }
}

public extension GlassButton {
    /// Wraps `GlassButton`'s action with a `.light` impact generator.
    /// Use in place of the bare initializer wherever the spec calls for
    /// floating chrome haptics (menu button, create button, glass chips).
    init(
        systemImage: String,
        diameter: CGFloat = 56,
        tint: Color = .white,
        haptic: Bool,
        action: @escaping () -> Void
    ) {
        if haptic {
            self.init(systemImage: systemImage, diameter: diameter, tint: tint) {
                TinctaHaptics.tap()
                action()
            }
        } else {
            self.init(systemImage: systemImage, diameter: diameter, tint: tint, action: action)
        }
    }
}
