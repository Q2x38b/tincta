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

/// Editable per-ingredient amount under a named size variation.
struct SizeAmountDraft: Identifiable, Equatable {
    let id: UUID
    /// Matches the IngredientDraft.id this override applies to.
    var ingredientID: UUID
    var quantityWhole: Int
    var fraction: Fraction?

    init(id: UUID = UUID(),
         ingredientID: UUID,
         quantityWhole: Int = 0,
         fraction: Fraction? = nil) {
        self.id = id
        self.ingredientID = ingredientID
        self.quantityWhole = quantityWhole
        self.fraction = fraction
    }

    init(from amount: SizeAmount) {
        self.id = amount.id
        self.ingredientID = amount.ingredientID
        self.quantityWhole = amount.quantityWhole
        self.fraction = amount.fraction
    }
}

/// Editable copy of a named size variation. Class (not struct) so the
/// per-ingredient amounts can be mutated through bindings in the size editor.
@Observable
final class RecipeSizeDraft: Identifiable {
    let id: UUID
    var name: String
    var sortOrder: Int
    var isDefault: Bool
    /// One entry per base ingredient. Index alignment is maintained by
    /// `RecipeEditorViewModel.syncSizeAmounts(to:)` whenever the base
    /// ingredient list changes.
    var amounts: [SizeAmountDraft]

    init(id: UUID = UUID(),
         name: String,
         sortOrder: Int,
         isDefault: Bool = false,
         amounts: [SizeAmountDraft] = []) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.amounts = amounts
    }

    init(from size: RecipeSize) {
        self.id = size.id
        self.name = size.name
        self.sortOrder = size.sortOrder
        self.isDefault = size.isDefault
        self.amounts = size.amounts.map(SizeAmountDraft.init(from:))
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
    var sizes: [RecipeSizeDraft]

    /// Currently expanded row, if any. Tapping a row toggles this.
    var expandedIngredientID: UUID?

    /// In-memory DrinkLook used by the Drink Builder for brand-new recipes.
    /// Persisted into the freshly-created Recipe on `save(in:)`. Nil until
    /// the user actually opens the builder.
    var workingDrinkLook: DrinkLook?

    init(recipe: Recipe?) {
        self.editingRecipe = recipe
        if let r = recipe {
            self.name = r.name
            self.directions = r.directions
            self.credit = r.credit ?? ""
            self.backgroundColorHex = r.backgroundColorHex
            self.ingredients = r.orderedIngredients.map(IngredientDraft.init(from:))
            self.sizes = r.orderedSizes.map(RecipeSizeDraft.init(from:))
        } else {
            self.name = ""
            self.directions = ""
            self.credit = ""
            self.backgroundColorHex = TinctaPalette.sage.hex
            self.ingredients = []
            self.sizes = []
        }
    }

    var isEditingExisting: Bool { editingRecipe != nil }

    /// Returns a DrinkLook the Drink Builder can mutate. For existing recipes
    /// this is the recipe's own DrinkLook (mutations persist via SwiftData).
    /// For new recipes a transient DrinkLook is created and persisted on save.
    func ensureDrinkLook() -> DrinkLook {
        if let existing = editingRecipe?.drinkLook { return existing }
        if let working = workingDrinkLook { return working }
        let fresh = DrinkLook(vessel: .rocks, drinkColorHex: "")
        workingDrinkLook = fresh
        return fresh
    }

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

    // MARK: - Size mutations

    /// Add a new size variation. Pass `multiplier` to pre-fill amounts as
    /// `base * multiplier` (snapped to standard bar fractions).
    func addSize(name: String, multiplier: Double = 1.0) {
        let nextOrder = (sizes.map(\.sortOrder).max() ?? -1) + 1
        let amounts = ingredients.map { draft -> SizeAmountDraft in
            let base = Double(draft.quantityWhole) + (draft.fraction?.value ?? 0)
            let raw = base * multiplier
            let whole = Int(raw)
            let frac = raw - Double(whole)
            let matched = Fraction.allCases.min(by: {
                abs($0.value - frac) < abs($1.value - frac)
            })
            let attached: Fraction? = matched.flatMap { abs($0.value - frac) < 0.06 ? $0 : nil }
            return SizeAmountDraft(
                ingredientID: draft.id,
                quantityWhole: whole,
                fraction: attached
            )
        }
        sizes.append(RecipeSizeDraft(
            name: name,
            sortOrder: nextOrder,
            isDefault: sizes.isEmpty,   // first added is the default
            amounts: amounts
        ))
    }

    func removeSize(id: UUID) {
        sizes.removeAll { $0.id == id }
        // If we removed the default, promote the first remaining.
        if !sizes.contains(where: \.isDefault), let first = sizes.first {
            first.isDefault = true
        }
    }

    /// Whenever the user adds/removes a base ingredient, every size has to
    /// gain or lose its corresponding amount slot so the override map stays
    /// in sync. Called automatically from the editor view.
    func syncSizeAmountsToIngredients() {
        let ingredientIDs = Set(ingredients.map(\.id))
        for size in sizes {
            // Drop overrides whose ingredient no longer exists.
            size.amounts.removeAll { !ingredientIDs.contains($0.ingredientID) }
            // Add slots for newly-added ingredients (default to base amount).
            for ing in ingredients where !size.amounts.contains(where: { $0.ingredientID == ing.id }) {
                size.amounts.append(SizeAmountDraft(
                    ingredientID: ing.id,
                    quantityWhole: ing.quantityWhole,
                    fraction: ing.fraction
                ))
            }
        }
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
            reconcileSizes(on: recipe, in: context)
        } else {
            let recipe = Recipe(
                name: trimmedName,
                directions: directions,
                backgroundColorHex: backgroundColorHex,
                credit: trimmedCredit.isEmpty ? nil : trimmedCredit,
                createdAt: now,
                updatedAt: now
            )
            // Persist the look the user shaped in the builder if they opened
            // it; otherwise fall back to an empty rocks glass.
            let look = workingDrinkLook ?? DrinkLook(vessel: .rocks, drinkColorHex: "")
            recipe.drinkLook = look
            context.insert(recipe)
            context.insert(look)
            attachIngredients(to: recipe, in: context)
            attachSizes(to: recipe, in: context)
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
    private func attachSizes(to recipe: Recipe, in context: ModelContext) {
        for draft in sizes {
            let size = RecipeSize(
                id: draft.id,
                name: draft.name.trimmingCharacters(in: .whitespaces),
                sortOrder: draft.sortOrder,
                isDefault: draft.isDefault
            )
            size.recipe = recipe
            context.insert(size)
            for amountDraft in draft.amounts {
                let amount = SizeAmount(
                    id: amountDraft.id,
                    ingredientID: amountDraft.ingredientID,
                    quantityWhole: amountDraft.quantityWhole,
                    fraction: amountDraft.fraction
                )
                amount.size = size
                context.insert(amount)
            }
        }
    }

    @MainActor
    private func reconcileSizes(on recipe: Recipe, in context: ModelContext) {
        let existingByID = Dictionary(uniqueKeysWithValues: recipe.sizes.map { ($0.id, $0) })
        let draftIDs = Set(sizes.map(\.id))

        // Delete removed sizes (cascade also drops their SizeAmount children).
        for (id, existing) in existingByID where !draftIDs.contains(id) {
            context.delete(existing)
        }

        // Update or insert each draft.
        for draft in sizes {
            if let existing = existingByID[draft.id] {
                existing.name = draft.name.trimmingCharacters(in: .whitespaces)
                existing.sortOrder = draft.sortOrder
                existing.isDefault = draft.isDefault
                reconcileSizeAmounts(on: existing, draft: draft, in: context)
            } else {
                let size = RecipeSize(
                    id: draft.id,
                    name: draft.name.trimmingCharacters(in: .whitespaces),
                    sortOrder: draft.sortOrder,
                    isDefault: draft.isDefault
                )
                size.recipe = recipe
                context.insert(size)
                for amountDraft in draft.amounts {
                    let amount = SizeAmount(
                        id: amountDraft.id,
                        ingredientID: amountDraft.ingredientID,
                        quantityWhole: amountDraft.quantityWhole,
                        fraction: amountDraft.fraction
                    )
                    amount.size = size
                    context.insert(amount)
                }
            }
        }
    }

    @MainActor
    private func reconcileSizeAmounts(on size: RecipeSize,
                                      draft: RecipeSizeDraft,
                                      in context: ModelContext) {
        let existingByID = Dictionary(uniqueKeysWithValues: size.amounts.map { ($0.id, $0) })
        let draftIDs = Set(draft.amounts.map(\.id))

        for (id, existing) in existingByID where !draftIDs.contains(id) {
            context.delete(existing)
        }

        for amountDraft in draft.amounts {
            if let existing = existingByID[amountDraft.id] {
                existing.ingredientID = amountDraft.ingredientID
                existing.quantityWhole = amountDraft.quantityWhole
                existing.fraction = amountDraft.fraction
            } else {
                let amount = SizeAmount(
                    id: amountDraft.id,
                    ingredientID: amountDraft.ingredientID,
                    quantityWhole: amountDraft.quantityWhole,
                    fraction: amountDraft.fraction
                )
                amount.size = size
                context.insert(amount)
            }
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
