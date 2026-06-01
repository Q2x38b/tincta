import Foundation
// Weak-linking the FoundationModels framework. Without this, dyld eagerly
// loads the entire on-device LLM framework at app launch (it's one of the
// heaviest SDK frameworks on iOS 26), which was a big slice of the cold-
// launch time the user has been seeing. With @_weakLinked, the framework
// is mapped lazily — only when we actually touch a symbol from it on the
// first Scan tap. SystemLanguageModel.default.availability already gates
// our usage to iOS 26 + Apple Intelligence devices, so a missing framework
// on older OSes is handled.
@_weakLinked import FoundationModels

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

    /// Touch `SystemLanguageModel.default` and prepare a session early so
    /// the first real scan doesn't pay the cold-start cost. Safe to call
    /// from a background task at app launch.
    static func prewarm() async {
        // Querying availability is enough to trigger the framework's lazy
        // init paths (loading model metadata, starting Apple Intelligence
        // services). We deliberately don't actually run inference here.
        _ = SystemLanguageModel.default.availability
        // Construct + warm a session if the model is ready. The session
        // builds compiler context which is the slow part on first use.
        guard isAvailable else { return }
        // Constructing the session triggers tokenizer/adapter init. We keep
        // it briefly via `_` so the compiler can't optimise it away.
        let session = LanguageModelSession(instructions: Self.systemInstructions)
        session.prewarm()
        _ = session
    }


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

        FRACTION RULES (read carefully — every fraction MUST emit in slash form):
        - The `fraction` field MUST be exactly one of: "", "1/8", "1/4", "1/3", "1/2", "2/3", "3/4".
        - NEVER emit the unicode glyphs ½ ⅓ ¼ ¾ ⅔ ⅛ — always convert to slash form.
        - "1 ½ oz", "1½ oz", "1.5 oz", "1 1/2 oz" → quantityWhole=1, fraction="1/2", unit="oz".
        - "¾ oz", "3/4 oz", ".75 oz" → quantityWhole=0, fraction="3/4", unit="oz".
        - "½ oz" → quantityWhole=0, fraction="1/2", unit="oz".
        - "2 oz" → quantityWhole=2, fraction="", unit="oz".
        - Decimals not in the set above (e.g. 1.4) → round to the nearest standard
          fraction. 1.4 → fraction="1/3" (1⅓ is closer than 1¼).
        - If no fractional part at all, emit fraction="" (empty string) — never "0" or "0/1".

        OTHER RULES:
        - "1 dash" → quantityWhole=1, fraction="", unit="dash".
        - "8 mint leaves" → quantityWhole=8, fraction="", unit="leaf", name="Mint".
        - "Top with club soda" → quantityWhole=0, fraction="", unit="top", name="Club Soda".
        - Strip trailing punctuation from ingredient names.
        - Recipe names use Title Case.
        - If a value is missing in the source, leave directions/credit empty rather than guessing.

        DIRECTIONS / NUMBERED STEPS:
        - Output directions as discrete steps separated by NEWLINES (\\n). The
          app numbers them automatically from line breaks — you do not write
          "1.", "2.", or "Step 1:" prefixes yourself.
        - One imperative per line. "Shake. Strain. Garnish." → three lines.
        - If the source already has explicit numbers ("1. Stir bourbon and
          syrup. 2. Strain into glass."), STRIP the numbers and keep the
          natural splits — same one-imperative-per-line shape.
        - If the source is one long paragraph, SPLIT it at the sentence
          boundaries that match procedural steps (verbs like Stir, Shake,
          Add, Strain, Pour, Top, Garnish, Express, Muddle, Build).
        - Don't paraphrase the words themselves — just split them up.
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
                fraction: Fraction.parse(ing.fraction),
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
