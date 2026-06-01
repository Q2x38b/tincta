import SwiftUI

// MARK: - Hex helpers

extension Color {
    /// Initialize from `#RRGGBB` or `RRGGBB`. Returns clear on a parse failure.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            self = .clear
            return
        }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// `#RRGGBB` form for storage. Falls back to "#000000" if introspection fails.
    var hexString: String {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return "#000000" }
        return String(format: "#%02X%02X%02X",
                      Int((r * 255).rounded()),
                      Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
        #else
        return "#000000"
        #endif
    }
}

// MARK: - Brand tokens

extension Color {
    static let tinctaInk        = Color(hex: "#1A1A1A")
    static let tinctaParchment  = Color(hex: "#F4EFE6")
    static let tinctaGlassStroke = Color.white.opacity(0.35)
    static let tinctaShadow     = Color.black.opacity(0.18)
}

/// Returns a foreground color (near-black or near-white) that contrasts well
/// against the given background. Used for card titles, where the background
/// color is user-chosen.
func contrastingForeground(forHex hex: String) -> Color {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    guard let v = UInt32(s, radix: 16) else { return .white }
    let r = Double((v >> 16) & 0xFF) / 255.0
    let g = Double((v >> 8) & 0xFF) / 255.0
    let b = Double(v & 0xFF) / 255.0
    // Relative luminance (sRGB)
    let lum = 0.2126 * gamma(r) + 0.7152 * gamma(g) + 0.0722 * gamma(b)
    return lum > 0.55 ? Color(hex: "#1F1F1F") : .white
}

private func gamma(_ c: Double) -> Double {
    c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
}

// MARK: - Tone-on-tone

extension Color {
    /// Returns a shade of the receiver suitable as secondary text on top of
    /// the receiver itself — slightly darker for light backgrounds, slightly
    /// lighter for dark backgrounds. Keeps the hue so the result reads as
    /// "of the card" rather than a contrasting overlay.
    ///
    /// Used for the ingredient lines on the collapsed Library cards — the
    /// title stays at full contrast (black/white) and the ingredients drop
    /// to this muted tone-on-tone, matching the reference screenshot.
    func toneOnTone() -> Color {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return self
        }
        // Light bg → darker shade; dark bg → lighter shade. Brightness
        // delta bumped again — ±0.45 still read too subtle on real
        // device. ±0.58 lands closer to typical "muted text on coloured
        // card" contrast used in editorial design.
        let newB: CGFloat = b > 0.55 ? max(0, b - 0.58) : min(1, b + 0.55)
        let newS: CGFloat = min(1, s * 1.25 + 0.10)
        return Color(hue: Double(h),
                     saturation: Double(newS),
                     brightness: Double(newB),
                     opacity: Double(a))
        #else
        return self
        #endif
    }
}
