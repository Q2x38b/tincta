import Foundation
import Observation

/// View-side state for the Recipe Detail screen.
///
/// Owns the two interactive controls in the bottom glass bar:
/// - `displayUnit`: which volumetric unit to render (.oz or .ml). Non-volumetric
///   units (leaf, sprig, wedge, …) are untouched by this toggle.
/// - `quantityMultiplier`: how many drinks to scale up to. Always applied to
///   every ingredient — including piece counts.
///
/// Neither value persists onto the `Recipe`; both are ephemeral, per-screen
/// state. The view re-renders when either changes.
@Observable
final class DetailViewModel {

    /// Which volumetric unit to display. Defaults to whatever the recipe
    /// already stores; the user can flip it with the OZ|ML segmented control.
    var displayUnit: Unit

    /// How many drinks to scale up. 1...12. Multiplies every ingredient amount.
    var quantityMultiplier: Int

    init(displayUnit: Unit = .oz, quantityMultiplier: Int = 1) {
        self.displayUnit = displayUnit
        self.quantityMultiplier = quantityMultiplier
    }

    // MARK: - API

    /// Resolved (quantity-string, unit-string, name) for a single ingredient,
    /// honoring both the OZ↔ML toggle and the QTY multiplier.
    ///
    /// Behaviour:
    /// - Volumetric units (oz/ml/cl/tsp/tbsp/dash/drop/splash) are converted to
    ///   `displayUnit` when that conversion is possible. We only convert
    ///   oz↔ml here — switching mL → ml is a no-op; switching tsp → oz would
    ///   change the unit label which we don't want, so non-target volumetric
    ///   units (tsp, tbsp, dash, drop, splash, cl) are left in their native
    ///   unit and only scaled by `quantityMultiplier`.
    /// - Non-volumetric/piece units (leaf, sprig, wedge, …) are left in their
    ///   native unit and scaled by `quantityMultiplier`.
    func scaledLine(for ingredient: Ingredient) -> (quantity: String, unit: String, name: String) {
        let multiplier = Double(max(1, quantityMultiplier))
        let baseAmount = ingredient.amount
        let sourceUnit = ingredient.unit

        // Decide the unit we'll actually render in.
        let targetUnit: Unit = {
            // Only oz <-> ml participate in the toggle — every other unit
            // keeps its native label.
            if sourceUnit == .oz || sourceUnit == .ml {
                return displayUnit == .ml ? .ml : .oz
            }
            return sourceUnit
        }()

        // Convert if needed (oz <-> ml). Otherwise keep the native amount.
        let converted: Double
        if targetUnit != sourceUnit,
           let value = UnitConversion.convert(amount: baseAmount, from: sourceUnit, to: targetUnit) {
            converted = value
        } else {
            converted = baseAmount
        }

        let scaled = converted * multiplier
        let quantityString = UnitConversion.formatAmount(scaled, unit: targetUnit)
        let unitLabel = targetUnit.display(forAmount: scaled)

        return (quantityString, unitLabel, ingredient.name)
    }

    // MARK: - Convenience

    /// Pick a sensible starting `displayUnit` given the recipe's ingredient mix.
    /// If any volumetric ingredient is stored in `.ml`, default to mL; otherwise
    /// default to oz.
    static func defaultDisplayUnit(for recipe: Recipe) -> Unit {
        let usesMl = recipe.orderedIngredients.contains { $0.unit == .ml }
        return usesMl ? .ml : .oz
    }
}
