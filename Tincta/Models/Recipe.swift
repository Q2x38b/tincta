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

    var createdAt: Date
    var updatedAt: Date
    var groupTags: [String]

    init(
        id: UUID = UUID(),
        name: String,
        directions: String = "",
        backgroundColorHex: String,
        credit: String? = nil,
        groupTags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.directions = directions
        self.backgroundColorHex = backgroundColorHex
        self.credit = credit
        self.groupTags = groupTags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Ingredients in the user-defined order.
    var orderedIngredients: [Ingredient] {
        ingredients.sorted { $0.order < $1.order }
    }
}

extension Recipe: Identifiable {}
