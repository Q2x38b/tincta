import SwiftUI
import SwiftData

/// A single overlapping card in the Library stack. Solid background colour
/// drawn from `recipe.backgroundColorHex`; title in full-contrast white/black;
/// ingredient lines in a tone-on-tone shade of the card so they read as
/// "of the card" rather than overlaid (matches the reference screenshot).
struct RecipeCardView: View {
    let recipe: Recipe
    let namespace: Namespace.ID

    /// Cap on ingredient lines previewed on the card. Most recipes are
    /// 3-5 ingredients so usually all of them fit; very long lists get
    /// truncated here to keep cards from growing absurdly tall.
    private let previewLineCount = 6
    /// Minimum card height — short recipes stop here. Recipes with more
    /// ingredients grow past this because we DON'T pin `.frame(height:)`.
    /// The parent VStack overlap + zIndex stacking still work regardless
    /// of individual card heights.
    private let cardMinHeight: CGFloat = 280

    var body: some View {
        let bgColor = Color(hex: recipe.backgroundColorHex)
        let titleColor = contrastingForeground(forHex: recipe.backgroundColorHex)
        // Ingredient lines use a tone-on-tone shade of the card colour, not
        // black/white. Lighter cards get a darker shade; darker cards get a
        // lighter shade. Saturation bumped slightly so it reads as in-family.
        let ingredientColor = bgColor.toneOnTone()
        let ingredients = Array(recipe.orderedIngredients.prefix(previewLineCount))

        VStack(alignment: .leading, spacing: 16) {
            Text(recipe.name)
                .font(.tinctaDisplay(22))
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .matchedGeometryEffect(id: "recipe-title-\(recipe.id)", in: namespace)

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

            if let credit = recipe.credit, !credit.isEmpty {
                Text(credit)
                    .font(.tinctaUILabel(11))
                    .foregroundStyle(ingredientColor.opacity(0.85))
            }
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
        // Tiny shadow — just enough to lift cards off the dark background.
        .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 3)
        .matchedTransitionSource(id: recipe.id, in: namespace)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(recipe.name))
        .accessibilityHint(Text("Tap to open recipe"))
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
