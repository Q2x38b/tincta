import SwiftUI

/// Typography tokens. The spec calls for New York (serif) for drink names and
/// ingredient lines (italic), SF Pro (sans) for body/directions and UI labels.
/// Both ship with the system on iOS 18+, so no licensing or embedding needed.
public enum TinctaFont {
    /// New York serif at the given point size and weight, optional italic.
    public static func serif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        let base = Font.system(size: size, weight: weight, design: .serif)
        return italic ? base.italic() : base
    }

    /// SF Pro at the given point size and weight. Wide tracking for caps labels.
    public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }
}

public extension Font {
    /// Display caps title used on card headers and recipe names.
    static func tinctaDisplay(_ size: CGFloat = 36) -> Font {
        TinctaFont.sans(size, weight: .semibold)
    }

    /// Italic serif used for ingredient lines like "BOURBON".
    static func tinctaIngredient(_ size: CGFloat = 24) -> Font {
        TinctaFont.serif(size, weight: .regular, italic: true)
    }

    /// Body sans used for directions and longform text.
    static func tinctaBody(_ size: CGFloat = 16) -> Font {
        TinctaFont.sans(size, weight: .regular)
    }

    /// Tight caps used for section labels like "INGREDIENTS", "DRINK NAME".
    static func tinctaUILabel(_ size: CGFloat = 12) -> Font {
        TinctaFont.sans(size, weight: .semibold)
    }
}

public extension View {
    /// Default dynamic type and base font tweaks applied at the App root.
    func tinctaTypography() -> some View {
        self.environment(\.font, .tinctaBody(16))
    }
}

/// Text view configured to look like the screenshot's ingredient line:
/// "2 oz BOURBON" — the number in roman, the unit small caps, the ingredient italic serif.
public struct IngredientLineText: View {
    public let quantity: String
    public let unit: String
    public let name: String
    public let pointSize: CGFloat

    public init(quantity: String, unit: String, name: String, pointSize: CGFloat = 22) {
        self.quantity = quantity
        self.unit = unit
        self.name = name
        self.pointSize = pointSize
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(quantity)
                .font(.tinctaIngredient(pointSize))
            if !unit.isEmpty {
                Text(unit.uppercased())
                    .font(.tinctaIngredient(pointSize * 0.7))
                    .tracking(0.6)
            }
            Text(name.uppercased())
                .font(.tinctaIngredient(pointSize))
        }
    }
}
