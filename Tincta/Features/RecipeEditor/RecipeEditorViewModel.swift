import Foundation
import SwiftData
import SwiftUI

/// Local, editable copy of an Ingredient. The view-model keeps an array of
/// these so users can Cancel out of an edit session without mutating the
/// underlying SwiftData objects.
struct IngredientDraft: Identifiable, Equatable {
    let id: UUID
    var quantityWhole: Int
    var fraction: Fraction?
    var unit: Unit
    var name: String

    init(
        id: UUID = UUID(),
        quantityWhole: Int = 0,
        fraction: Fraction? = nil,
        unit: Unit = .oz,
        name: String = ""
    ) {
        self.id = id
        self.quantityWhole = quantityWhole
        self.fraction = fraction
        self.unit = unit
        self.name = name
    }

    init(from ingredient: Ingredient) {
        self.id = ingredient.id
        self.quantityWhole = ingredient.quantityWhole
        self.fraction = ingredient.fraction
        self.unit = ingredient.unit
        self.name = ingredient.name
    }

    /// Same string the live ingredient line will render, for the collapsed row.
    var displayLine: String {
        let qty = Ingredient.formatQuantity(whole: quantityWhole, fraction: fraction)
        let amt = Double(quantityWhole) + (fraction?.value ?? 0)
        let unitWord = unit.display(forAmount: amt)
        if unitWord.isEmpty {
            return "\(qty) \(name.uppercased())"
        }
        return "\(qty) \(unitWord) \(name.uppercased())"
    }
}

/// View-model that owns a draft copy of the edited recipe's fields. Persists
/// to SwiftData only when `save(in:)` is called; `cancel()` simply discards.
@Observable
final class RecipeEditorViewModel {
    /// nil when the editor is being used to create a new recipe.
    let editingRecipe: Recipe?

    var name: String
    var directions: String
    var credit: String
    var backgroundColorHex: String
    var ingredients: [IngredientDraft]

    /// Currently expanded row, if any. Tapping a row toggles this.
    var expandedIngredientID: UUID?

    init(recipe: Recipe?) {
        self.editingRecipe = recipe
        if let r = recipe {
            self.name = r.name
            self.directions = r.directions
            self.credit = r.credit ?? ""
            self.backgroundColorHex = r.backgroundColorHex
            self.ingredients = r.orderedIngredients.map(IngredientDraft.init(from:))
        } else {
            self.name = ""
            self.directions = ""
            self.credit = ""
            self.backgroundColorHex = TinctaPalette.sage.hex
            self.ingredients = []
        }
    }

    var isEditingExisting: Bool { editingRecipe != nil }

    // MARK: - Ingredient mutations

    func addIngredient() {
        let draft = IngredientDraft()
        ingredients.append(draft)
        expandedIngredientID = draft.id
    }

    func removeIngredients(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }

    func moveIngredients(from source: IndexSet, to destination: Int) {
        ingredients.move(fromOffsets: source, toOffset: destination)
    }

    func toggleExpand(_ id: UUID) {
        expandedIngredientID = (expandedIngredientID == id) ? nil : id
    }

    func binding(for id: UUID) -> Binding<IngredientDraft>? {
        guard let idx = ingredients.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.ingredients[idx] },
            set: { self.ingredients[idx] = $0 }
        )
    }

    // MARK: - Persistence

    /// Commits the draft state to SwiftData. Creates a new Recipe (and
    /// DrinkLook) if `editingRecipe` is nil.
    @MainActor
    func save(in context: ModelContext) {
        let now = Date.now
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCredit = credit.trimmingCharacters(in: .whitespacesAndNewlines)

        if let recipe = editingRecipe {
            recipe.name = trimmedName
            recipe.directions = directions
            recipe.credit = trimmedCredit.isEmpty ? nil : trimmedCredit
            recipe.backgroundColorHex = backgroundColorHex
            recipe.updatedAt = now
            reconcileIngredients(on: recipe, in: context)
        } else {
            let recipe = Recipe(
                name: trimmedName,
                directions: directions,
                backgroundColorHex: backgroundColorHex,
                credit: trimmedCredit.isEmpty ? nil : trimmedCredit,
                createdAt: now,
                updatedAt: now
            )
            let look = DrinkLook(vessel: .rocks, drinkColorHex: "")
            recipe.drinkLook = look
            context.insert(recipe)
            context.insert(look)
            attachIngredients(to: recipe, in: context)
        }

        try? context.save()
    }

    @MainActor
    func delete(in context: ModelContext) {
        guard let recipe = editingRecipe else { return }
        context.delete(recipe)
        try? context.save()
    }

    // MARK: - Helpers

    @MainActor
    private func attachIngredients(to recipe: Recipe, in context: ModelContext) {
        for (idx, draft) in ingredients.enumerated() {
            let ing = Ingredient(
                id: draft.id,
                quantityWhole: draft.quantityWhole,
                fraction: draft.fraction,
                unit: draft.unit,
                name: draft.name,
                order: idx
            )
            ing.recipe = recipe
            context.insert(ing)
        }
    }

    @MainActor
    private func reconcileIngredients(on recipe: Recipe, in context: ModelContext) {
        let existingByID = Dictionary(uniqueKeysWithValues: recipe.ingredients.map { ($0.id, $0) })
        let draftIDs = Set(ingredients.map(\.id))

        // Delete removed
        for (id, existing) in existingByID where !draftIDs.contains(id) {
            context.delete(existing)
        }

        // Update or insert
        for (idx, draft) in ingredients.enumerated() {
            if let existing = existingByID[draft.id] {
                existing.quantityWhole = draft.quantityWhole
                existing.fraction = draft.fraction
                existing.unit = draft.unit
                existing.name = draft.name
                existing.order = idx
            } else {
                let ing = Ingredient(
                    id: draft.id,
                    quantityWhole: draft.quantityWhole,
                    fraction: draft.fraction,
                    unit: draft.unit,
                    name: draft.name,
                    order: idx
                )
                ing.recipe = recipe
                context.insert(ing)
            }
        }
    }
}
