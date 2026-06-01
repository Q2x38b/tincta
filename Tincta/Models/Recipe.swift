import Foundation
import SwiftData

@Model
final class Recipe {
    @Attribute(.unique) var id: UUID
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    var ingredients: [Ingredient] = []

    var directions: String
    var backgroundColorHex: String
    var credit: String?

    @Relationship(deleteRule: .cascade, inverse: \DrinkLook.recipe)
    var drinkLook: DrinkLook?

    @Relationship(deleteRule: .cascade, inverse: \RecipeSize.recipe)
    var sizes: [RecipeSize] = []

    var createdAt: Date
    var updatedAt: Date
    var groupTags: [String]
    /// Manual position in the Library card stack. Lower = earlier in the
    /// list. Drag-to-reorder rewrites this. Defaults to 0; on first
    /// Library appear, a one-shot migration assigns sequential values to
    /// every recipe based on existing createdAt-desc order.
    var sortOrder: Int = 0

    init(
        id: UUID = UUID(),
        name: String,
        directions: String = "",
        backgroundColorHex: String,
        credit: String? = nil,
        groupTags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.directions = directions
        self.backgroundColorHex = backgroundColorHex
        self.credit = credit
        self.groupTags = groupTags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }

    /// Ingredients in the user-defined order.
    var orderedIngredients: [Ingredient] {
        ingredients.sorted { $0.order < $1.order }
    }
}

extension Recipe: Identifiable {}
