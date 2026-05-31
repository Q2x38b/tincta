import Foundation
import SwiftData

/// First-run seed: Old Fashioned, Tom Collins, Mint Julep — the three drinks
/// shown in the design mocks. Also a stable starting point for previews.
enum SeedData {

    static func populate(context: ModelContext) {
        for recipe in starters() {
            context.insert(recipe)
        }
        try? context.save()
    }

    static func starters() -> [Recipe] {
        [oldFashioned(), tomCollins(), mintJulep()]
    }

    // MARK: - Old Fashioned

    static func oldFashioned() -> Recipe {
        let recipe = Recipe(
            name: "Old Fashioned",
            directions: """
            Stir the bourbon, simple syrup, and bitters in a mixing glass with ice.
            Strain into a rocks glass with one large ice cube.
            Garnish with an orange peel.
            """,
            backgroundColorHex: TinctaPalette.rust.hex,
            credit: nil
        )
        let look = DrinkLook(
            vessel: .rocks,
            drinkColorHex: TinctaPalette.amberLiquid.hex,
            ice: .huge,
            citrus: [.orangePeel],
            garnishes: [],
            extras: []
        )
        look.recipe = recipe
        recipe.drinkLook = look
        recipe.ingredients = [
            Ingredient(quantityWhole: 2, fraction: nil,        unit: .oz,   name: "Bourbon",          order: 0),
            Ingredient(quantityWhole: 0, fraction: .quarter,   unit: .oz,   name: "Simple Syrup (1:1)", order: 1),
            Ingredient(quantityWhole: 1, fraction: nil,        unit: .dash, name: "Angostura Bitters", order: 2),
            Ingredient(quantityWhole: 1, fraction: nil,        unit: .dash, name: "Orange Bitters",    order: 3),
        ]
        recipe.ingredients.forEach { $0.recipe = recipe }
        return recipe
    }

    // MARK: - Tom Collins

    static func tomCollins() -> Recipe {
        let recipe = Recipe(
            name: "Tom Collins",
            directions: """
            Combine gin, simple syrup, and lemon juice in a shaker with ice. Shake well.
            Strain into a Collins glass filled with ice.
            Top with club soda. Garnish with a lemon wheel.
            """,
            backgroundColorHex: TinctaPalette.gold.hex
        )
        let look = DrinkLook(
            vessel: .collins,
            drinkColorHex: TinctaPalette.paleLiquid.hex,
            ice: .cubes,
            citrus: [.lemonWheel],
            garnishes: [],
            extras: [.straw]
        )
        look.recipe = recipe
        recipe.drinkLook = look
        recipe.ingredients = [
            Ingredient(quantityWhole: 2, fraction: nil,            unit: .oz, name: "Gin",                 order: 0),
            Ingredient(quantityWhole: 0, fraction: .threeQuarters, unit: .oz, name: "Simple Syrup (1:1)", order: 1),
            Ingredient(quantityWhole: 0, fraction: .threeQuarters, unit: .oz, name: "Lemon Juice",         order: 2),
            Ingredient(quantityWhole: 0, fraction: nil,            unit: .top, name: "Club Soda",          order: 3),
        ]
        recipe.ingredients.forEach { $0.recipe = recipe }
        return recipe
    }

    // MARK: - Mint Julep

    static func mintJulep() -> Recipe {
        let recipe = Recipe(
            name: "Mint Julep",
            directions: """
            Lightly muddle mint leaves with simple syrup in a julep cup.
            Add bourbon and pack with crushed ice. Stir until the cup frosts.
            Top with more crushed ice and garnish with a mint sprig.
            """,
            backgroundColorHex: TinctaPalette.sage.hex
        )
        let look = DrinkLook(
            vessel: .rocks,
            drinkColorHex: TinctaPalette.amberLiquid.hex,
            ice: .crushed,
            citrus: [],
            garnishes: [.mintSprig],
            extras: [.straw]
        )
        look.recipe = recipe
        recipe.drinkLook = look
        recipe.ingredients = [
            Ingredient(quantityWhole: 2, fraction: nil,       unit: .oz,    name: "Bourbon",            order: 0),
            Ingredient(quantityWhole: 8, fraction: nil,       unit: .leaf,  name: "Mint",               order: 1),
            Ingredient(quantityWhole: 1, fraction: nil,       unit: .sprig, name: "Mint",               order: 2),
            Ingredient(quantityWhole: 0, fraction: .half,     unit: .oz,    name: "Simple Syrup (1:1)", order: 3),
        ]
        recipe.ingredients.forEach { $0.recipe = recipe }
        return recipe
    }
}
