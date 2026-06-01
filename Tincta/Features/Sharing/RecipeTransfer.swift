import Foundation

// MARK: - Top-level envelope

/// Wire-format envelope for exporting one or more recipes from Tincta. Keep the
/// schema additive: new optional fields are fine, breaking changes bump
/// `schemaVersion`.
struct RecipeTransfer: Codable, Sendable, Equatable {
    /// Current wire schema. Start at 1 and bump only on breaking changes.
    static let currentSchemaVersion: Int = 1

    let schemaVersion: Int
    let recipes: [RecipePayload]

    init(schemaVersion: Int = RecipeTransfer.currentSchemaVersion,
                recipes: [RecipePayload]) {
        self.schemaVersion = schemaVersion
        self.recipes = recipes
    }
}

// MARK: - Recipe payload

struct RecipePayload: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let directions: String
    let backgroundColorHex: String
    let credit: String?
    let groupTags: [String]
    let ingredients: [IngredientPayload]
    let drinkLook: DrinkLookPayload?
    /// Optional sized variants (e.g. "Regular", "Grande", "Pitcher"). Each
    /// size carries per-ingredient quantity overrides referenced by the
    /// ingredient's payload id. Older payloads predate this field — keep it
    /// optional so a `nil` decode still works.
    let sizes: [SizePayload]?

    init(
        id: UUID,
        name: String,
        directions: String,
        backgroundColorHex: String,
        credit: String?,
        groupTags: [String],
        ingredients: [IngredientPayload],
        drinkLook: DrinkLookPayload?,
        sizes: [SizePayload]? = nil
    ) {
        self.id = id
        self.name = name
        self.directions = directions
        self.backgroundColorHex = backgroundColorHex
        self.credit = credit
        self.groupTags = groupTags
        self.ingredients = ingredients
        self.drinkLook = drinkLook
        self.sizes = sizes
    }
}

// MARK: - Size payload

/// One named size variant for a recipe (e.g. "Regular", "Grande").
/// Per-ingredient amount overrides live in `amounts`, keyed by the payload
/// id of the base `IngredientPayload`. Missing overrides inherit the
/// recipe's base amount.
struct SizePayload: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let sortOrder: Int
    let isDefault: Bool
    let amounts: [SizeAmountPayload]

    init(
        id: UUID,
        name: String,
        sortOrder: Int,
        isDefault: Bool,
        amounts: [SizeAmountPayload]
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.amounts = amounts
    }
}

struct SizeAmountPayload: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    /// Matches `IngredientPayload.id` on the parent recipe payload. The
    /// importer maps source-payload ingredient UUIDs to newly-inserted
    /// Ingredient UUIDs before resolving these references.
    let ingredientID: UUID
    let quantityWhole: Int
    let fractionRaw: String?

    init(
        id: UUID,
        ingredientID: UUID,
        quantityWhole: Int,
        fractionRaw: String?
    ) {
        self.id = id
        self.ingredientID = ingredientID
        self.quantityWhole = quantityWhole
        self.fractionRaw = fractionRaw
    }
}

// MARK: - Ingredient payload

struct IngredientPayload: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let quantityWhole: Int
    /// Raw value of `Fraction` (e.g. "1/2"); nil = no fractional component.
    let fractionRaw: String?
    /// Raw value of `Unit` (e.g. "oz", "dash").
    let unitRaw: String
    let name: String
    let order: Int

    init(
        id: UUID,
        quantityWhole: Int,
        fractionRaw: String?,
        unitRaw: String,
        name: String,
        order: Int
    ) {
        self.id = id
        self.quantityWhole = quantityWhole
        self.fractionRaw = fractionRaw
        self.unitRaw = unitRaw
        self.name = name
        self.order = order
    }
}

// MARK: - Drink look payload

struct DrinkLookPayload: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let vesselRaw: String
    let drinkColorHex: String
    let iceRaw: String?
    let citrusRaw: [String]
    let garnishRaw: [String]
    let extrasRaw: [String]

    init(
        id: UUID,
        vesselRaw: String,
        drinkColorHex: String,
        iceRaw: String?,
        citrusRaw: [String],
        garnishRaw: [String],
        extrasRaw: [String]
    ) {
        self.id = id
        self.vesselRaw = vesselRaw
        self.drinkColorHex = drinkColorHex
        self.iceRaw = iceRaw
        self.citrusRaw = citrusRaw
        self.garnishRaw = garnishRaw
        self.extrasRaw = extrasRaw
    }
}

// MARK: - Errors

enum RecipeTransferError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case malformedPayload
    case emptyPayload

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            return "This shared recipe uses schema v\(found), but this version of Tincta only understands v\(supported). Update the app to import it."
        case .malformedPayload:
            return "The shared link could not be read. It may be incomplete or corrupted."
        case .emptyPayload:
            return "The shared link did not contain any recipes."
        }
    }
}

// MARK: - Mappers (Model -> Payload)

extension RecipePayload {
    /// Build a payload from a live SwiftData `Recipe`. We snapshot identifiers
    /// from the source for round-tripping; the importer always assigns fresh
    /// UUIDs to avoid PK collisions.
    init(recipe: Recipe) {
        let sizePayloads = recipe.orderedSizes.map(SizePayload.init(size:))
        self.init(
            id: recipe.id,
            name: recipe.name,
            directions: recipe.directions,
            backgroundColorHex: recipe.backgroundColorHex,
            credit: recipe.credit,
            groupTags: recipe.groupTags,
            ingredients: recipe.orderedIngredients.map(IngredientPayload.init(ingredient:)),
            drinkLook: recipe.drinkLook.map(DrinkLookPayload.init(drinkLook:)),
            sizes: sizePayloads.isEmpty ? nil : sizePayloads
        )
    }
}

extension SizePayload {
    init(size: RecipeSize) {
        self.init(
            id: size.id,
            name: size.name,
            sortOrder: size.sortOrder,
            isDefault: size.isDefault,
            amounts: size.amounts.map(SizeAmountPayload.init(amount:))
        )
    }
}

extension SizeAmountPayload {
    init(amount: SizeAmount) {
        self.init(
            id: amount.id,
            ingredientID: amount.ingredientID,
            quantityWhole: amount.quantityWhole,
            fractionRaw: amount.fractionRaw
        )
    }
}

extension IngredientPayload {
    init(ingredient: Ingredient) {
        self.init(
            id: ingredient.id,
            quantityWhole: ingredient.quantityWhole,
            fractionRaw: ingredient.fractionRaw,
            unitRaw: ingredient.unitRaw,
            name: ingredient.name,
            order: ingredient.order
        )
    }
}

extension DrinkLookPayload {
    init(drinkLook: DrinkLook) {
        self.init(
            id: drinkLook.id,
            vesselRaw: drinkLook.vesselRaw,
            drinkColorHex: drinkLook.drinkColorHex,
            iceRaw: drinkLook.iceRaw,
            citrusRaw: drinkLook.citrusRaw,
            garnishRaw: drinkLook.garnishRaw,
            extrasRaw: drinkLook.extrasRaw
        )
    }
}
