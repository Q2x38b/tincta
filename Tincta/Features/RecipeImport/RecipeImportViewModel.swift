import Foundation
import SwiftData
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// Drives the end-to-end import flow: receive images → OCR → on-device LLM
/// parse → present editable drafts → save to SwiftData.
@MainActor
@Observable
final class RecipeImportViewModel {

    enum Stage: Equatable {
        case empty                    // initial; no images yet
        case capturing                // user is taking more shots from camera
        case processing(progress: String)
        case ready                    // drafts available for review
        case finished                 // recipes have been saved
        case failed(String)
    }

    var stage: Stage = .empty
    var images: [UIImage] = []
    var drafts: [RecipeDraft] = []
    /// One palette swatch hex picked round-robin so new recipes don't all
    /// share the same background.
    private var paletteCursor = 0

    // MARK: - Image collection

    func add(images newImages: [UIImage]) {
        images.append(contentsOf: newImages)
    }

    func clear() {
        images.removeAll()
        drafts.removeAll()
        stage = .empty
    }

    // MARK: - Process

    /// Run OCR on every queued image, then parse with the on-device LLM. On
    /// completion, `drafts` contains one editable `RecipeDraft` per parsed
    /// recipe (or a single fallback draft if the LLM isn't available).
    func process() async {
        guard !images.isEmpty else { return }
        stage = .processing(progress: "Reading text from \(images.count) image\(images.count == 1 ? "" : "s")…")

        let pages = await OCRService.recognize(in: images)
        let transcripts = pages.map(\.text).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !transcripts.isEmpty else {
            stage = .failed("Couldn't read any text from those images. Try a sharper photo.")
            return
        }

        if RecipeParser.isAvailable {
            stage = .processing(progress: "Parsing recipes on device…")
            do {
                let parsed = try await RecipeParser.parse(transcripts: transcripts)
                if parsed.isEmpty {
                    drafts = [RecipeDraft.from(rawText: transcripts.joined(separator: "\n\n"),
                                               backgroundColorHex: nextPaletteHex())]
                } else {
                    drafts = parsed.map { RecipeDraft.from(parsed: $0,
                                                           backgroundColorHex: nextPaletteHex()) }
                }
                stage = .ready
            } catch {
                // Even if the LLM blows up, give the user the OCR text so the
                // import isn't a dead-end.
                drafts = [RecipeDraft.from(rawText: transcripts.joined(separator: "\n\n"),
                                           backgroundColorHex: nextPaletteHex(),
                                           notice: "On-device parser failed: \(error.localizedDescription). Edit manually.")]
                stage = .ready
            }
        } else {
            let reason = RecipeParser.unavailabilityReason ?? "On-device AI not available."
            drafts = [RecipeDraft.from(rawText: transcripts.joined(separator: "\n\n"),
                                       backgroundColorHex: nextPaletteHex(),
                                       notice: reason + " You can paste the text into ingredients or directions and edit.")]
            stage = .ready
        }
    }

    // MARK: - Persistence

    func save(in context: ModelContext) {
        let enabled = drafts.filter(\.isIncluded)
        for draft in enabled {
            let recipe = draft.materialize()
            context.insert(recipe)
            if let look = recipe.drinkLook {
                context.insert(look)
            }
            for ingredient in recipe.ingredients {
                context.insert(ingredient)
            }
        }
        try? context.save()
        stage = .finished
    }

    // MARK: - Helpers

    private func nextPaletteHex() -> String {
        let palette = [TinctaPalette.sage, TinctaPalette.gold, TinctaPalette.rust, TinctaPalette.cream, TinctaPalette.mauve]
        let pick = palette[paletteCursor % palette.count]
        paletteCursor += 1
        return pick.hex
    }
}

// MARK: - RecipeDraft

/// Editable copy of a parsed recipe. Lives apart from SwiftData so users can
/// freely tweak before we commit.
@Observable
final class RecipeDraft: Identifiable {
    let id = UUID()
    var name: String
    var directions: String
    var credit: String
    var backgroundColorHex: String
    var ingredients: [IngredientLineDraft]
    var notice: String?           // explanatory banner shown above the row
    var isIncluded: Bool = true

    init(name: String,
         directions: String,
         credit: String,
         backgroundColorHex: String,
         ingredients: [IngredientLineDraft],
         notice: String? = nil) {
        self.name = name
        self.directions = directions
        self.credit = credit
        self.backgroundColorHex = backgroundColorHex
        self.ingredients = ingredients
        self.notice = notice
    }

    static func from(parsed: ParsedRecipe, backgroundColorHex: String) -> RecipeDraft {
        RecipeDraft(
            name: parsed.name,
            directions: parsed.directions,
            credit: parsed.credit ?? "",
            backgroundColorHex: backgroundColorHex,
            ingredients: parsed.ingredients.map { IngredientLineDraft(parsed: $0) }
        )
    }

    /// Fallback when the LLM is unavailable or returned nothing — the user
    /// gets a draft pre-filled with the raw OCR transcript.
    static func from(rawText: String,
                     backgroundColorHex: String,
                     notice: String? = "Couldn't auto-parse — review and edit before saving.") -> RecipeDraft {
        RecipeDraft(
            name: "Scanned Recipe",
            directions: rawText,
            credit: "",
            backgroundColorHex: backgroundColorHex,
            ingredients: [],
            notice: notice
        )
    }

    func materialize() -> Recipe {
        let recipe = Recipe(
            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Recipe" : name,
            directions: directions,
            backgroundColorHex: backgroundColorHex,
            credit: credit.trimmingCharacters(in: .whitespaces).isEmpty ? nil : credit
        )
        let look = DrinkLook(vessel: .rocks, drinkColorHex: "")
        recipe.drinkLook = look
        recipe.ingredients = ingredients.enumerated().map { idx, ing in
            Ingredient(
                quantityWhole: max(0, ing.quantityWhole),
                fraction: ing.fraction,
                unit: ing.unit,
                name: ing.name,
                order: idx
            )
        }
        return recipe
    }

    func addIngredient() {
        ingredients.append(IngredientLineDraft())
    }

    func removeIngredients(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }
}

@Observable
final class IngredientLineDraft: Identifiable {
    let id = UUID()
    var quantityWhole: Int
    var fraction: Fraction?
    var unit: Unit
    var name: String

    init(quantityWhole: Int = 0,
         fraction: Fraction? = nil,
         unit: Unit = .oz,
         name: String = "") {
        self.quantityWhole = quantityWhole
        self.fraction = fraction
        self.unit = unit
        self.name = name
    }

    convenience init(parsed: ParsedIngredient) {
        self.init(
            quantityWhole: max(0, parsed.quantityWhole),
            fraction: Fraction(rawValue: parsed.fraction),
            unit: Unit(rawValue: parsed.unit) ?? .oz,
            name: parsed.name.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
