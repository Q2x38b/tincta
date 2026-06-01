import SwiftUI
import SwiftData

/// A single overlapping card in the Library stack. Solid background colour
/// drawn from `recipe.backgroundColorHex`; title in full-contrast white/black;
/// ingredient lines in a tone-on-tone shade of the card so they read as
/// "of the card" rather than overlaid (matches the reference screenshot).
struct RecipeCardView: View {
    let recipe: Recipe
    let namespace: Namespace.ID
    /// Optional match info from a filter pass. When set to .ingredient(name)
    /// or .tag(name), the card renders a small "Contains X" badge so the
    /// user can see WHY this card matched their search query. Pass nil for
    /// non-search contexts (eg. the natural Library scroll).
    var matchHint: LibraryViewModel.MatchKind? = nil

    /// Hard ceiling so a 20-ingredient recipe doesn't make a card the
    /// size of the screen. Most recipes have 3-5 ingredients so this
    /// rarely matters.
    private let previewLineCap = 12
    /// Minimum card height — short recipes stop here. Recipes with more
    /// ingredients grow past this because we DON'T pin `.frame(height:)`.
    private let cardMinHeight: CGFloat = 280

    var body: some View {
        let bgColor = Color(hex: recipe.backgroundColorHex)
        let titleColor = contrastingForeground(forHex: recipe.backgroundColorHex)
        // Ingredient lines use a tone-on-tone shade of the card colour, not
        // black/white. Lighter cards get a darker shade; darker cards get a
        // lighter shade. Saturation bumped slightly so it reads as in-family.
        let ingredientColor = bgColor.toneOnTone()
        let ingredients = Array(recipe.orderedIngredients.prefix(previewLineCap))

        VStack(alignment: .leading, spacing: 16) {
            Text(recipe.name)
                .font(.tinctaDisplay(22))
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .matchedGeometryEffect(id: "recipe-title-\(recipe.id)", in: namespace)

            // "Contains X" badge — only when the active search matched on
            // an ingredient or tag (not on the recipe name itself), so the
            // user can see WHY this card came back. Centered under the
            // title, tone-on-tone with the card colour.
            if let containsLabel {
                Text(containsLabel)
                    .font(.tinctaUILabel(11))
                    .foregroundStyle(ingredientColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .strokeBorder(ingredientColor.opacity(0.45), lineWidth: 0.8)
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Reduced inter-line spacing 8 → 4 so the ingredient block reads
            // as one tight block rather than a loose list.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(ingredients, id: \.id) { ingredient in
                    IngredientLineText(
                        quantity: Ingredient.formatQuantity(
                            whole: ingredient.quantityWhole,
                            fraction: ingredient.fraction
                        ),
                        unit: ingredient.unit.display(forAmount: ingredient.amount),
                        name: ingredient.name,
                        pointSize: 18
                    )
                    .foregroundStyle(ingredientColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 0)

            // Credit footer removed per request — Recipe.credit data still
            // exists on the model but no view reads it.
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Variable height: cards size to content but never shorter than
        // `cardMinHeight`. With 4-ingredient previewLineCount this caps the
        // growth too — recipes with 5+ ingredients clip to the prefix
        // anyway, so cards never get monstrously tall.
        .frame(minHeight: cardMinHeight)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(bgColor)
                .matchedGeometryEffect(id: "recipe-card-\(recipe.id)", in: namespace)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        // Shadows are applied OUTSIDE this view, in LibraryView's
        // visualEffect — so they can fade to 0 when this card pins at the
        // top of the viewport (otherwise stacked-at-top cards would have
        // their shadows piling on each other and look muddy).
        .matchedTransitionSource(id: recipe.id, in: namespace)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(recipe.name))
        .accessibilityHint(Text("Tap to open recipe"))
    }

    /// Returns the "Contains X" string to show under the title when the
    /// active search matched on something other than the recipe name.
    /// Returns nil for `.name` matches and when no hint is provided —
    /// the badge stays hidden in those cases.
    private var containsLabel: String? {
        switch matchHint {
        case .ingredient(let name):
            return "Contains \(name)"
        case .tag(let tag):
            return "Tagged \(tag)"
        case .direction(let snippet):
            // Keep the badge a single short line — long directions get
            // ellipsised so the card height doesn't jump around.
            let max = 44
            let clean = snippet.replacingOccurrences(of: "\n", with: " ")
            if clean.count > max {
                let cut = clean.index(clean.startIndex, offsetBy: max - 1)
                return "Step: \(clean[..<cut])…"
            }
            return "Step: \(clean)"
        case .credit(let credit):
            return "From \(credit)"
        case .name, nil:
            return nil
        }
    }
}

#Preview {
    PreviewWrapper()
        .modelContainer(TinctaModelContainer.makePreview())
}

private struct PreviewWrapper: View {
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Namespace private var ns

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(recipes) { recipe in
                    RecipeCardView(recipe: recipe, namespace: ns)
                }
            }
            .padding(24)
        }
        .background(Color.tinctaInk.ignoresSafeArea())
    }
}
