import SwiftUI
import SwiftData

/// A single overlapping card in the Library stack. Matches Image 1 of the
/// design mocks: large display caps title, italic serif ingredient lines,
/// solid background color drawn from `recipe.backgroundColorHex`.
struct RecipeCardView: View {
    let recipe: Recipe
    /// Namespace and id used by integration to wire the matched-geometry
    /// expand animation into RecipeDetailView.
    let namespace: Namespace.ID

    private let previewLineCount = 4
    /// Tighter card height matching the user's mock — title + ~3 ingredient
    /// lines visible above the next card's bleed.
    private let cardHeight: CGFloat = 420

    var body: some View {
        let foreground = contrastingForeground(forHex: recipe.backgroundColorHex)
        let ingredients = Array(recipe.orderedIngredients.prefix(previewLineCount))

        VStack(alignment: .leading, spacing: 18) {
            Text(recipe.name.uppercased())
                .font(.tinctaDisplay(22))
                .tracking(0.4)
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .matchedGeometryEffect(id: "recipe-title-\(recipe.id)", in: namespace)

            Rectangle()
                .fill(foreground.opacity(0.35))
                .frame(height: 0.7)

            VStack(alignment: .leading, spacing: 8) {
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
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 0)

            if let credit = recipe.credit, !credit.isEmpty {
                Text(credit.uppercased())
                    .font(.tinctaUILabel(10))
                    .tracking(1.2)
                    .foregroundStyle(foreground.opacity(0.7))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(hex: recipe.backgroundColorHex))
                .matchedGeometryEffect(id: "recipe-card-\(recipe.id)", in: namespace)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        // Tiny shadow — just enough to lift cards off the dark background.
        .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 3)
        // iOS 18+ hero-transition source. The sheet destination uses the
        // matching id to expand the detail OUT OF this card's frame instead
        // of doing the default slide-up-from-bottom sheet animation.
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
        .background(Color.tinctaParchment.ignoresSafeArea())
    }
}
