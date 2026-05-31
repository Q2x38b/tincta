import Foundation

// MARK: - Fraction

/// Fractional amounts used in cocktail measures. Whole numbers live alongside
/// these on `Ingredient.quantityWhole`; the total amount is `whole + fraction`.
public enum Fraction: String, CaseIterable, Codable, Sendable, Identifiable {
    case eighth      = "1/8"
    case quarter     = "1/4"
    case third       = "1/3"
    case half        = "1/2"
    case twoThirds   = "2/3"
    case threeQuarters = "3/4"

    public var id: String { rawValue }

    public var value: Double {
        switch self {
        case .eighth:          return 1.0 / 8.0
        case .quarter:         return 1.0 / 4.0
        case .third:           return 1.0 / 3.0
        case .half:            return 1.0 / 2.0
        case .twoThirds:       return 2.0 / 3.0
        case .threeQuarters:   return 3.0 / 4.0
        }
    }

    public var display: String {
        switch self {
        case .eighth:          return "⅛"
        case .quarter:         return "¼"
        case .third:           return "⅓"
        case .half:            return "½"
        case .twoThirds:       return "⅔"
        case .threeQuarters:   return "¾"
        }
    }
}

// MARK: - Unit

/// Every measurement a bar-relevant recipe might use. Conversion to mL lives in
/// `UnitConversion`. Units that don't have a sensible mL equivalent (e.g. `leaf`,
/// `wedge`) return `nil` from the conversion and are never scaled by OZ↔ML toggles.
public enum Unit: String, CaseIterable, Codable, Sendable, Identifiable {
    case oz
    case ml
    case cl
    case tsp          // barspoon
    case tbsp
    case dash
    case drop
    case splash
    case part
    case pinch
    case cube
    case wedge
    case wheel
    case slice
    case sprig
    case leaf
    case twist
    case peel
    case rim
    case scoop
    case can
    case bottle
    case count        // bare whole items, e.g. "8 mint leaves"
    case top          // "top with…"

    public var id: String { rawValue }

    /// User-facing short-caps label as rendered in the ingredient line.
    public var display: String {
        switch self {
        case .oz:     return "oz"
        case .ml:     return "ml"
        case .cl:     return "cl"
        case .tsp:    return "tsp"
        case .tbsp:   return "tbsp"
        case .dash:   return "dash"
        case .drop:   return "drop"
        case .splash: return "splash"
        case .part:   return "part"
        case .pinch:  return "pinch"
        case .cube:   return "cube"
        case .wedge:  return "wedge"
        case .wheel:  return "wheel"
        case .slice:  return "slice"
        case .sprig:  return "sprig"
        case .leaf:   return "leaf"
        case .twist:  return "twist"
        case .peel:   return "peel"
        case .rim:    return "rim"
        case .scoop:  return "scoop"
        case .can:    return "can"
        case .bottle: return "bottle"
        case .count:  return ""
        case .top:    return "top"
        }
    }

    /// Plural form used when amount > 1. Some units never pluralize.
    public func display(forAmount amount: Double) -> String {
        let plural = amount > 1.0 + .ulpOfOne
        switch self {
        case .oz, .ml, .cl, .tsp, .tbsp, .part, .pinch, .top:
            return display
        case .dash:    return plural ? "dashes"   : "dash"
        case .drop:    return plural ? "drops"    : "drop"
        case .splash:  return plural ? "splashes" : "splash"
        case .cube:    return plural ? "cubes"    : "cube"
        case .wedge:   return plural ? "wedges"   : "wedge"
        case .wheel:   return plural ? "wheels"   : "wheel"
        case .slice:   return plural ? "slices"   : "slice"
        case .sprig:   return plural ? "sprigs"   : "sprig"
        case .leaf:    return plural ? "leaves"   : "leaf"
        case .twist:   return plural ? "twists"   : "twist"
        case .peel:    return plural ? "peels"    : "peel"
        case .rim:     return plural ? "rims"     : "rim"
        case .scoop:   return plural ? "scoops"   : "scoop"
        case .can:     return plural ? "cans"     : "can"
        case .bottle:  return plural ? "bottles"  : "bottle"
        case .count:   return ""
        }
    }

    /// Whether this unit participates in OZ↔ML conversion. Volumetric units do;
    /// piece-count units (leaf, sprig, etc.) do not.
    public var isVolumetric: Bool {
        UnitConversion.milliliters(forOne: self) != nil
    }
}

// MARK: - Vessel

public enum Vessel: String, CaseIterable, Codable, Sendable, Identifiable {
    case rocks
    case collins
    case highball
    case snifter
    case coupe
    case martini
    case nickAndNora    = "nick_and_nora"
    case hurricane
    case copperMug      = "copper_mug"
    case wine
    case flute
    case shot
    case tiki

    public var id: String { rawValue }

    public var display: String {
        switch self {
        case .rocks:        return "Rocks"
        case .collins:      return "Collins"
        case .highball:     return "Highball"
        case .snifter:      return "Snifter"
        case .coupe:        return "Coupe"
        case .martini:      return "Martini"
        case .nickAndNora:  return "Nick & Nora"
        case .hurricane:    return "Hurricane"
        case .copperMug:    return "Copper Mug"
        case .wine:         return "Wine"
        case .flute:        return "Flute"
        case .shot:         return "Shot"
        case .tiki:         return "Tiki"
        }
    }
}

// MARK: - Ice

public enum IceType: String, CaseIterable, Codable, Sendable, Identifiable {
    case huge       // one large cube
    case cubes
    case crushed
    case none

    public var id: String { rawValue }

    public var display: String {
        switch self {
        case .huge:     return "Huge"
        case .cubes:    return "Cubes"
        case .crushed:  return "Crushed"
        case .none:     return "None"
        }
    }
}

// MARK: - Citrus

public enum Citrus: String, CaseIterable, Codable, Sendable, Identifiable {
    case lemonTwist        = "lemon_twist"
    case lemonWedge        = "lemon_wedge"
    case lemonPeel         = "lemon_peel"
    case lemonWheel        = "lemon_wheel"
    case limeTwist         = "lime_twist"
    case limeWedge         = "lime_wedge"
    case limeWheel         = "lime_wheel"
    case orangeTwist       = "orange_twist"
    case orangePeel        = "orange_peel"
    case orangeWheel       = "orange_wheel"
    case grapefruitPeel    = "grapefruit_peel"

    public var id: String { rawValue }

    public var display: String {
        switch self {
        case .lemonTwist:      return "Lemon Twist"
        case .lemonWedge:      return "Lemon Wedge"
        case .lemonPeel:       return "Lemon Peel"
        case .lemonWheel:      return "Lemon Wheel"
        case .limeTwist:       return "Lime Twist"
        case .limeWedge:       return "Lime Wedge"
        case .limeWheel:       return "Lime Wheel"
        case .orangeTwist:     return "Orange Twist"
        case .orangePeel:      return "Orange Peel"
        case .orangeWheel:     return "Orange Wheel"
        case .grapefruitPeel:  return "Grapefruit Peel"
        }
    }
}

// MARK: - Garnish

public enum Garnish: String, CaseIterable, Codable, Sendable, Identifiable {
    case cherry
    case olive
    case mintSprig       = "mint_sprig"
    case rosemary
    case cinnamonStick   = "cinnamon_stick"
    case starAnise       = "star_anise"
    case cucumber
    case edibleFlower    = "edible_flower"
    case sugarRim        = "sugar_rim"
    case saltRim         = "salt_rim"

    public var id: String { rawValue }

    public var display: String {
        switch self {
        case .cherry:         return "Cherry"
        case .olive:          return "Olive"
        case .mintSprig:      return "Mint Sprig"
        case .rosemary:       return "Rosemary"
        case .cinnamonStick:  return "Cinnamon Stick"
        case .starAnise:      return "Star Anise"
        case .cucumber:       return "Cucumber"
        case .edibleFlower:   return "Edible Flower"
        case .sugarRim:       return "Sugar Rim"
        case .saltRim:        return "Salt Rim"
        }
    }
}

// MARK: - Extra

public enum Extra: String, CaseIterable, Codable, Sendable, Identifiable {
    case straw
    case umbrella
    case stirrer

    public var id: String { rawValue }

    public var display: String {
        switch self {
        case .straw:     return "Straw"
        case .umbrella:  return "Umbrella"
        case .stirrer:   return "Stirrer"
        }
    }
}
