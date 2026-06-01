import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Typography tokens.
///
/// The "fancy font" used for ingredient lines and the recipe title is the
/// `serif(...)` helper. It tries a list of **preferred custom serifs** first
/// (drop their `.ttf` / `.otf` into the asset bundle + register in
/// `project.yml`'s `Info.plist > UIAppFonts` and they're picked up
/// automatically). Falls back to Apple's system serif (New York) with
/// modernised weight + leading.
///
/// Recommended drops, all under SIL Open Font License — explicitly safe to
/// bundle commercially (the license requires you to include the OFL text
/// somewhere in your distribution; I'd put it in the About screen):
///
///   - **Fraunces** (fonts.google.com/specimen/Fraunces) — variable serif
///     with optical sizes. The most "modern" feeling of the open serifs;
///     designed for contemporary editorial. *First preference.*
///   - **Crimson Pro** (fonts.google.com/specimen/Crimson+Pro) — clean
///     transitional, great for body text.
///   - **EB Garamond** (fonts.google.com/specimen/EB+Garamond) — classical
///     but elegant, if you want a more old-world feel.
///   - **Source Serif 4** (Adobe, OFL) — neutral and very legible.
///
/// To enable any of them: download the font family, drag the .ttf files
/// into the Xcode project (target = Tincta), and add the filenames under
/// `project.yml > targets > Tincta > info > properties > UIAppFonts: [...]`.
/// The lookup below uses the family name (which doesn't include extension).
public enum TinctaFont {

    /// Family names tried in order before the system serif fallback. First
    /// one that is actually registered in the app bundle wins. Add new
    /// candidates here — no other code needs to change.
    private static let preferredSerifFamilies: [String] = [
        "Crimson Pro",       // ← bundled in Tincta/Resources/Fonts (OFL v1.1)
        "Fraunces",
        "Fraunces 9pt",
        "EB Garamond",
        "Source Serif 4",
        "Source Serif Pro",
        "Lora",
    ]

    /// Resolved once at startup. nil = no custom serif is bundled, use the
    /// system fallback. We resolve eagerly so the lookup isn't repeated per
    /// `.font()` call (which would be hot during scrolling).
    private static let resolvedSerifFamily: String? = {
        #if canImport(UIKit)
        let available = Set(UIFont.familyNames)
        return preferredSerifFamilies.first { available.contains($0) }
        #else
        return nil
        #endif
    }()

    /// Returns a "fancy" serif at the given point size + weight + italic.
    /// Uses the first registered custom serif family if any are present,
    /// otherwise Apple's New York with leading slightly tightened to feel
    /// more like a contemporary editorial typeface than a stock system font.
    public static func serif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        if let family = resolvedSerifFamily,
           let postscript = postscriptName(for: family, weight: weight, italic: italic) {
            // Custom font — render at exact point size.
            return Font.custom(postscript, size: size)
        }
        // System fallback: New York via design: .serif. We use `.light` for
        // ingredients (overridden by callers passing weight: .regular when
        // they want default), and bias italic with a slightly lower weight
        // to soften the strokes.
        let base = Font.system(size: size, weight: weight, design: .serif)
        return italic ? base.italic() : base
    }

    /// SF Pro at the given point size and weight.
    public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    // MARK: - PostScript name resolution

    /// PostScript names follow a `<Family>-<Style>` convention for the
    /// fonts we recommend. We try a couple of style spellings to cover
    /// minor variations between distributions.
    private static func postscriptName(for family: String, weight: Font.Weight, italic: Bool) -> String? {
        #if canImport(UIKit)
        let familyKey = family.replacingOccurrences(of: " ", with: "")
        let weightToken: String
        switch weight {
        case .ultraLight, .thin:    weightToken = italic ? "ThinItalic"     : "Thin"
        case .light:                weightToken = italic ? "LightItalic"    : "Light"
        case .regular:              weightToken = italic ? "Italic"         : "Regular"
        case .medium:               weightToken = italic ? "MediumItalic"   : "Medium"
        case .semibold:             weightToken = italic ? "SemiBoldItalic" : "SemiBold"
        case .bold:                 weightToken = italic ? "BoldItalic"     : "Bold"
        case .heavy, .black:        weightToken = italic ? "BlackItalic"    : "Black"
        default:                    weightToken = italic ? "Italic"         : "Regular"
        }
        let candidates = [
            "\(familyKey)-\(weightToken)",
            "\(family.replacingOccurrences(of: " ", with: ""))Roman-\(weightToken)",
            italic ? "\(familyKey)-Italic" : "\(familyKey)-Regular",
        ]
        let registered = Set(UIFont.fontNames(forFamilyName: family))
        return candidates.first { registered.contains($0) }
        #else
        return nil
        #endif
    }
}

public extension Font {
    /// Display title used on card headers and the recipe-detail title.
    /// Switched to `design: .rounded` (SF Rounded) — softer letterforms
    /// that pair better with the serif ingredient lines than default SF Pro.
    static func tinctaDisplay(_ size: CGFloat = 36) -> Font {
        Font.system(size: size, weight: .semibold, design: .rounded)
    }

    /// Font used for ingredient lines.
    /// Previously a light italic serif (Crimson Pro / New York). Switched
    /// to plain SF at regular weight per user request — the serif italic
    /// was reading as too "recipe book" / formal for a tool the user wants
    /// to feel native. SF here keeps the cards looking like the rest of
    /// iOS without sacrificing density.
    static func tinctaIngredient(_ size: CGFloat = 24) -> Font {
        Font.system(size: size, weight: .regular)
    }

    /// Body sans used for directions and longform text.
    static func tinctaBody(_ size: CGFloat = 16) -> Font {
        TinctaFont.sans(size, weight: .regular)
    }

    /// Sentence-case section label used everywhere across the UI.
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
/// "2 oz Bourbon" — the number in roman, the unit small caps, the ingredient
/// italic serif.
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
