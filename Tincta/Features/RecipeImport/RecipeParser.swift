import Foundation
import FoundationModels

/// Structured-output types for the on-device parser.
///
/// `@Generable` makes these usable as the `generating:` target of a
/// `LanguageModelSession`, which is how Apple's on-device LLM emits
/// JSON-shaped results we can consume directly as Swift values.

@Generable
struct ParsedRecipeBatch {
    @Guide(description: "Every distinct cocktail or drink recipe present in the source text. If only one recipe is present, return a single element. Skip any non-recipe text (headings, page numbers, ads).")
    let recipes: [ParsedRecipe]
}

@Generable
struct ParsedRecipe {
    @Guide(description: "Display name of the cocktail (e.g. 'Old Fashioned'). Use title case.")
    let name: String

    @Guide(description: "Ordered list of ingredients exactly as they appear in the recipe.")
    let ingredients: [ParsedIngredient]

    @Guide(description: "Free-text directions for preparing the drink. Each step on its own line. Leave empty if the source has no method.")
    let directions: String

    @Guide(description: "Attribution for the recipe if present (bartender, bar, book). Omit if not in the source.")
    let credit: String?
}

@Generable
struct ParsedIngredient {
    @Guide(description: "Whole-number part of the quantity (e.g. 2 for '2 oz', 1 for '1 ½ oz', 0 for '¾ oz'). Use 0 if there is no whole part.")
    let quantityWhole: Int

    @Guide(description: "Fractional part, if any. One of: '1/8', '1/4', '1/3', '1/2', '2/3', '3/4'. Empty string for no fraction.")
    let fraction: String

    @Guide(description: "Unit of measure. Use one of: oz, ml, cl, tsp, tbsp, dash, drop, splash, part, pinch, cube, wedge, wheel, slice, sprig, leaf, twist, peel, rim, scoop, can, bottle, count, top. Use 'count' for bare items like '8 mint leaves' that have a number but no obvious unit. Use 'top' for 'top with…' ingredients.")
    let unit: String

    @Guide(description: "Ingredient name, no quantity (e.g. 'Bourbon', 'Simple Syrup (1:1)', 'Lemon Juice').")
    let name: String
}

/// Parses raw OCR transcripts into structured recipe data using Apple's
/// on-device Foundation Models LLM. The parser is **fully on-device**: no
/// data leaves the user's phone.
enum RecipeParser {

    /// Whether the on-device model is currently available on this device.
    /// Returns false on devices without Apple Intelligence, when the OS is
    /// downloading model assets, or when the user has it disabled.
    static var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:        return true
        case .unavailable:      return false
        @unknown default:       return false
        }
    }

    /// Reason the model is unavailable, surfaced to the user in the import
    /// review screen when parsing was skipped.
    static var unavailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence on-device models."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to parse scanned recipes."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still downloading. Try again in a few minutes."
        case .unavailable(let other):
            return "On-device AI is unavailable (\(other))."
        @unknown default:
            return "On-device AI is unavailable."
        }
    }

    /// Parse one or more OCR transcripts into structured recipes. Joins the
    /// transcripts with explicit page markers so the LLM can tell when one
    /// recipe ends and another begins.
    static func parse(transcripts: [String]) async throws -> [ParsedRecipe] {
        let joined = transcripts.enumerated().map { idx, text in
            "=== Page \(idx + 1) ===\n\(text)"
        }.joined(separator: "\n\n")
        return try await parse(rawText: joined)
    }

    static func parse(rawText: String) async throws -> [ParsedRecipe] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let session = LanguageModelSession(instructions: Self.systemInstructions)

        let response = try await session.respond(
            to: """
            Extract every cocktail or mixed-drink recipe from the OCR transcript \
            below into structured form. If multiple recipes appear (separated by \
            "=== Page N ===" markers or visible section breaks), return each as \
            its own entry. Discard non-recipe text such as headings, page numbers, \
            footers, and decorative copy.

            Transcript:
            \(trimmed)
            """,
            generating: ParsedRecipeBatch.self
        )
        return response.content.recipes
    }

    private static var systemInstructions: String {
        """
        You convert noisy OCR of cocktail recipe images into clean, structured \
        recipe records. You are precise about units (oz vs ml) and never invent \
        ingredients that aren't in the source.

        - Quantities like "1 ½ oz" become quantityWhole=1, fraction="1/2", unit="oz".
        - Quantities like "¾ oz" become quantityWhole=0, fraction="3/4", unit="oz".
        - "1 dash" becomes quantityWhole=1, fraction="", unit="dash".
        - "8 mint leaves" becomes quantityWhole=8, fraction="", unit="leaf", name="Mint".
        - "Top with club soda" becomes quantityWhole=0, fraction="", unit="top", name="Club Soda".
        - Strip trailing punctuation from ingredient names.
        - Preserve directions verbatim, one step per line. Don't paraphrase or shorten.
        - Recipe names use Title Case.
        - If a value is missing in the source, leave directions/credit empty rather than guessing.
        """
    }
}

// MARK: - Bridge to SwiftData

extension ParsedRecipe {
    /// Build a transient `Recipe` (+ children) from the parsed payload. The
    /// caller decides whether to insert into a `ModelContext`.
    func makeRecipe(backgroundColorHex: String) -> Recipe {
        let recipe = Recipe(
            name: name.isEmpty ? "Untitled Recipe" : name,
            directions: directions,
            backgroundColorHex: backgroundColorHex,
            credit: credit?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        )
        let look = DrinkLook(vessel: .rocks, drinkColorHex: "")
        recipe.drinkLook = look

        recipe.ingredients = ingredients.enumerated().map { idx, ing in
            Ingredient(
                quantityWhole: max(0, ing.quantityWhole),
                fraction: Fraction(rawValue: ing.fraction),
                unit: Unit(rawValue: ing.unit) ?? .oz,
                name: ing.name.trimmingCharacters(in: .whitespacesAndNewlines),
                order: idx
            )
        }
        return recipe
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
