import SwiftUI

/// The curated, designer-muted color palette used as recipe backgrounds and as
/// the source of swatches in the Color Picker. Each entry has a hex and a hue
/// family so the picker can group bands by family.
public struct TinctaSwatch: Identifiable, Hashable {
    public let id: String      // stable token, e.g. "sage_500"
    public let name: String    // human label, e.g. "Sage"
    public let hex: String
    public let family: Family

    public enum Family: String, CaseIterable, Identifiable {
        case teal, sage, mint, gold, cream, mauve, berry, rust, amber, slate
        public var id: String { rawValue }
        public var display: String {
            switch self {
            case .teal:  return "Teal"
            case .sage:  return "Sage"
            case .mint:  return "Mint"
            case .gold:  return "Gold"
            case .cream: return "Cream"
            case .mauve: return "Mauve"
            case .berry: return "Berry"
            case .rust:  return "Rust"
            case .amber: return "Amber"
            case .slate: return "Slate"
            }
        }
    }
}

public enum TinctaPalette {
    // Named tokens used by seed data and the design system itself.
    public static let sage   = TinctaSwatch(id: "sage_500",  name: "Sage",   hex: "#8A9F76", family: .sage)
    public static let gold   = TinctaSwatch(id: "gold_500",  name: "Gold",   hex: "#D8C76A", family: .gold)
    public static let rust   = TinctaSwatch(id: "rust_700",  name: "Rust",   hex: "#B14A1E", family: .rust)
    public static let cream  = TinctaSwatch(id: "cream_300", name: "Cream",  hex: "#EBE0CB", family: .cream)
    public static let mauve  = TinctaSwatch(id: "mauve_400", name: "Mauve",  hex: "#B68F88", family: .mauve)

    // Liquid colors for drink fills (not background swatches).
    public static let amberLiquid = TinctaSwatch(id: "liquid_amber", name: "Amber",   hex: "#C8843B", family: .amber)
    public static let paleLiquid  = TinctaSwatch(id: "liquid_pale",  name: "Pale",    hex: "#E8E2C0", family: .cream)

    /// The full picker palette, in hue-band order — mirrors Choose Color screens.
    /// Curated, designer-muted. ~60 swatches across 10 hue families so the
    /// user has real depth/variety without falling off into eye-burning neon.
    public static let all: [TinctaSwatch] = [
        // Teals — cool blue-greens
        .init(id: "teal_900",  name: "Midnight Teal", hex: "#243A3D", family: .teal),
        .init(id: "teal_800",  name: "Deep Sea",      hex: "#2F4F52", family: .teal),
        .init(id: "teal_700",  name: "Deep Teal",     hex: "#3F5C5F", family: .teal),
        .init(id: "teal_500",  name: "Teal",          hex: "#588A8E", family: .teal),
        .init(id: "teal_400",  name: "Lagoon",        hex: "#7AAAAC", family: .teal),
        .init(id: "teal_300",  name: "Sky Teal",      hex: "#A6C8CA", family: .teal),

        // Sages — muted greens
        .init(id: "sage_900",  name: "Forest",        hex: "#2F4A36", family: .sage),
        .init(id: "sage_700",  name: "Pine",          hex: "#5C7C66", family: .sage),
        .init(id: "sage_500",  name: "Sage",          hex: "#8A9F76", family: .sage),
        .init(id: "sage_400",  name: "Soft Sage",     hex: "#A8B894", family: .sage),
        .init(id: "sage_300",  name: "Pale Sage",     hex: "#C2D0B0", family: .sage),

        // Mints — cool light greens
        .init(id: "mint_500",  name: "Mint",          hex: "#8FC2A8", family: .mint),
        .init(id: "mint_300",  name: "Sea Foam",      hex: "#B5D0C5", family: .mint),
        .init(id: "mint_200",  name: "Frost",         hex: "#D6E6DD", family: .mint),

        // Golds — warm muted yellows
        .init(id: "gold_800",  name: "Honey",         hex: "#8C7426", family: .gold),
        .init(id: "gold_700",  name: "Antique Gold",  hex: "#A99A47", family: .gold),
        .init(id: "gold_500",  name: "Gold",          hex: "#D8C76A", family: .gold),
        .init(id: "gold_400",  name: "Buttercup",     hex: "#E2D478", family: .gold),
        .init(id: "gold_300",  name: "Light Gold",    hex: "#E9DC8B", family: .gold),
        .init(id: "gold_200",  name: "Pale Straw",    hex: "#F0E5A8", family: .gold),

        // Creams — warm light neutrals
        .init(id: "cream_600", name: "Sand",          hex: "#D8C9A6", family: .cream),
        .init(id: "cream_500", name: "Buttercream",   hex: "#E6D9B7", family: .cream),
        .init(id: "cream_400", name: "Linen",         hex: "#EEE4CC", family: .cream),
        .init(id: "cream_300", name: "Cream",         hex: "#EBE0CB", family: .cream),
        .init(id: "cream_200", name: "Parchment",     hex: "#F4EFE6", family: .cream),

        // Mauves — dusty pink-purples
        .init(id: "mauve_800", name: "Wine",          hex: "#5A3A40", family: .mauve),
        .init(id: "mauve_600", name: "Dusty Rose",    hex: "#8E6868", family: .mauve),
        .init(id: "mauve_400", name: "Mauve",         hex: "#B68F88", family: .mauve),
        .init(id: "mauve_300", name: "Blush",         hex: "#CFA9A1", family: .mauve),
        .init(id: "mauve_200", name: "Powder",        hex: "#E0C9C3", family: .mauve),

        // Berries — saturated red-violets
        .init(id: "berry_800", name: "Bordeaux",      hex: "#42283A", family: .berry),
        .init(id: "berry_700", name: "Plum",          hex: "#5E3F4F", family: .berry),
        .init(id: "berry_500", name: "Berry",         hex: "#A85469", family: .berry),
        .init(id: "berry_400", name: "Hibiscus",      hex: "#BE7283", family: .berry),
        .init(id: "berry_300", name: "Rosé",          hex: "#D69AA6", family: .berry),

        // Rusts / reds — warm earthy reds
        .init(id: "red_400",   name: "Salmon",        hex: "#D58974", family: .rust),
        .init(id: "red_500",   name: "Coral",         hex: "#C76A5A", family: .rust),
        .init(id: "rust_500",  name: "Rust",          hex: "#B86245", family: .rust),
        .init(id: "rust_700",  name: "Old Fashioned", hex: "#B14A1E", family: .rust),
        .init(id: "rust_800",  name: "Brick",         hex: "#7E331A", family: .rust),
        .init(id: "rust_900",  name: "Mahogany",      hex: "#5C2410", family: .rust),

        // Ambers — orange-browns
        .init(id: "amber_300", name: "Apricot",       hex: "#E2A773", family: .amber),
        .init(id: "amber_500", name: "Caramel",       hex: "#C68441", family: .amber),
        .init(id: "amber_700", name: "Amber",         hex: "#965D2D", family: .amber),
        .init(id: "amber_800", name: "Bourbon",       hex: "#6E411F", family: .amber),
        .init(id: "amber_900", name: "Espresso",      hex: "#3E2616", family: .amber),

        // Slates — cool grays
        .init(id: "slate_300", name: "Mist",          hex: "#A8A1AC", family: .slate),
        .init(id: "slate_500", name: "Slate",         hex: "#5C5664", family: .slate),
        .init(id: "slate_700", name: "Charcoal",      hex: "#3A3640", family: .slate),
        .init(id: "slate_900", name: "Onyx",          hex: "#1F1C24", family: .slate),
    ]

    /// Lookup by hex (case-insensitive). Returns nil if not in the curated set.
    public static func swatch(forHex hex: String) -> TinctaSwatch? {
        let needle = hex.uppercased()
        return all.first { $0.hex.uppercased() == needle }
    }

    /// Grouped by hue family, in palette order, for the Color Picker UI.
    public static func grouped() -> [(TinctaSwatch.Family, [TinctaSwatch])] {
        var groups: [TinctaSwatch.Family: [TinctaSwatch]] = [:]
        for s in all { groups[s.family, default: []].append(s) }
        return TinctaSwatch.Family.allCases.compactMap { fam in
            guard let list = groups[fam], !list.isEmpty else { return nil }
            return (fam, list)
        }
    }
}
