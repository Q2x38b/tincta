import Foundation

/// Conversion tables and helpers for OZ↔ML and recipe scaling.
///
/// `milliliters(forOne:)` returns the mL equivalent of one of the unit, or `nil`
/// for piece-count units (`leaf`, `wedge`, `sprig`, etc.) that don't convert.
public enum UnitConversion {

    /// US fluid ounce in mL. (1 US fl oz ≈ 29.5735 mL.)
    public static let ozInMl: Double = 29.5735

    /// mL equivalent of one of the given unit. Returns nil for piece units.
    public static func milliliters(forOne unit: Unit) -> Double? {
        switch unit {
        case .oz:     return ozInMl
        case .ml:     return 1.0
        case .cl:     return 10.0
        case .tsp:    return 5.0        // bar teaspoon
        case .tbsp:   return 15.0
        case .dash:   return 0.92       // ~1/32 oz
        case .drop:   return 0.05
        case .splash: return 5.0
        case .part, .pinch,
             .cube, .wedge, .wheel, .slice,
             .sprig, .leaf, .twist, .peel,
             .rim, .scoop, .can, .bottle,
             .count, .top:
            return nil
        }
    }

    /// Convert an amount expressed in `from` to `to`. Returns nil if either side
    /// is not volumetric (in which case the caller should not offer the toggle).
    public static func convert(amount: Double, from: Unit, to: Unit) -> Double? {
        guard let fromMl = milliliters(forOne: from),
              let toMl = milliliters(forOne: to) else { return nil }
        return amount * fromMl / toMl
    }

    /// Pretty-print a scaled amount with reasonable precision and fractions.
    /// - oz/cl/tbsp/tsp: keep one decimal, then collapse common fractions.
    /// - ml: integer.
    /// - dash/drop/splash/etc.: integer.
    public static func formatAmount(_ amount: Double, unit: Unit) -> String {
        switch unit {
        case .ml:
            return String(Int(amount.rounded()))
        case .oz, .cl, .tsp, .tbsp:
            return formatFractional(amount)
        default:
            // piece units & dash/drop — show as whole number when close
            if abs(amount - amount.rounded()) < 0.05 {
                return String(Int(amount.rounded()))
            }
            return formatFractional(amount)
        }
    }

    /// Render `amount` as `"<whole> <fraction>"` collapsing to standard bar fractions.
    /// e.g. 1.5 -> "1 ½", 0.75 -> "¾", 0.333… -> "⅓".
    public static func formatFractional(_ amount: Double) -> String {
        let whole = Int(amount)
        let frac = amount - Double(whole)
        let candidates: [(Double, String)] = [
            (1.0 / 8.0, "⅛"),
            (1.0 / 4.0, "¼"),
            (1.0 / 3.0, "⅓"),
            (1.0 / 2.0, "½"),
            (2.0 / 3.0, "⅔"),
            (3.0 / 4.0, "¾"),
            (7.0 / 8.0, "⅞"),
        ]
        let tolerance = 0.04
        if let match = candidates.first(where: { abs(frac - $0.0) < tolerance }) {
            return whole == 0 ? match.1 : "\(whole) \(match.1)"
        }
        if frac < tolerance {
            return "\(whole)"
        }
        if frac > 1 - tolerance {
            return "\(whole + 1)"
        }
        // Fallback: one-decimal
        return String(format: "%.1f", amount)
    }
}
