import Foundation
import SwiftData

/// Named size variation for a recipe — e.g. "Single", "Double", "Pitcher".
/// Each size carries per-ingredient overrides so a "Pitcher" can scale
/// some ingredients more than others (real cocktails don't always scale
/// linearly).
@Model
final class RecipeSize {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Stable order in the size picker UI.
    var sortOrder: Int
    /// The size shown initially when the recipe is opened.
    var isDefault: Bool

    @Relationship(deleteRule: .cascade, inverse: \SizeAmount.size)
    var amounts: [SizeAmount] = []

    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isDefault = isDefault
    }

    /// Convenience: build a size whose amounts mirror the base recipe times
    /// `multiplier`. Used by the editor's "Quick add" presets.
    static func scaled(
        name: String,
        multiplier: Double,
        from baseIngredients: [Ingredient],
        sortOrder: Int = 0
    ) -> RecipeSize {
        let size = RecipeSize(name: name, sortOrder: sortOrder)
        size.amounts = baseIngredients.map { ing in
            SizeAmount.scaled(from: ing, by: multiplier)
        }
        return size
    }
}

/// Per-ingredient override that lives under a `RecipeSize`. The override is
/// keyed by `ingredientID` (matches `Ingredient.id` on the parent recipe).
/// If a size has no override for an ingredient, the recipe's base amount is
/// used unchanged.
@Model
final class SizeAmount {
    @Attribute(.unique) var id: UUID
    /// Matches the `Ingredient.id` on the parent recipe.
    var ingredientID: UUID
    var quantityWhole: Int
    var fractionRaw: String?
    var size: RecipeSize?

    init(
        id: UUID = UUID(),
        ingredientID: UUID,
        quantityWhole: Int,
        fraction: Fraction? = nil
    ) {
        self.id = id
        self.ingredientID = ingredientID
        self.quantityWhole = quantityWhole
        self.fractionRaw = fraction?.rawValue
    }

    var fraction: Fraction? {
        get { fractionRaw.flatMap(Fraction.init(rawValue:)) }
        set { fractionRaw = newValue?.rawValue }
    }

    /// Combined whole + fraction amount this size should display.
    var amount: Double {
        Double(quantityWhole) + (fraction?.value ?? 0)
    }

    /// Build an override that's `base * multiplier`, snapping to the
    /// nearest standard bar fraction so "1 oz × 1.5" becomes "1½ oz"
    /// rather than "1.5 oz".
    static func scaled(from base: Ingredient, by multiplier: Double) -> SizeAmount {
        let raw = base.amount * multiplier
        let whole = Int(raw)
        let frac = raw - Double(whole)
        let matched = Fraction.allCases.min(by: {
            abs($0.value - frac) < abs($1.value - frac)
        })
        // Only attach a fraction if it's actually close — otherwise drop it.
        let frTol: Double = 0.06
        let attached: Fraction? = matched.flatMap { abs($0.value - frac) < frTol ? $0 : nil }
        return SizeAmount(
            ingredientID: base.id,
            quantityWhole: whole,
            fraction: attached
        )
    }
}

// MARK: - Recipe extension

extension Recipe {
    /// Sized variations the user has defined for this recipe, in display order.
    var orderedSizes: [RecipeSize] {
        sizes.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The size that should be selected when the detail view opens.
    var defaultSize: RecipeSize? {
        orderedSizes.first(where: \.isDefault) ?? orderedSizes.first
    }
}
