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

    /// Maximum number of ingredient lines previewed on the card. The mocks
    /// show four lines before the next card peeks through.
    private let previewLineCount = 4
    /// Approximate fixed card height. Cards overlap by ~120pt (set in parent),
    /// so the next card's title peeks through under this one.
    private let cardHeight: CGFloat = 520

    var body: some View {
        let foreground = contrastingForeground(forHex: recipe.backgroundColorHex)
        let ingredients = Array(recipe.orderedIngredients.prefix(previewLineCount))

        VStack(alignment: .leading, spacing: 24) {
            // Title block — large display caps, wrapped to the card width.
            Text(recipe.name.uppercased())
                .font(.tinctaDisplay(56))
                .tracking(-0.5)
                .lineSpacing(-6)
                .foregroundStyle(foreground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .matchedGeometryEffect(id: "recipe-title-\(recipe.id)", in: namespace)

            // Hairline divider tinted to the foreground for contrast.
            Rectangle()
                .fill(foreground.opacity(0.35))
                .frame(height: 0.7)

            // Ingredient preview lines. Italic serif, drawn in the card's
            // contrasting foreground.
            VStack(alignment: .leading, spacing: 10) {
                ForEach(ingredients, id: \.id) { ingredient in
                    IngredientLineText(
                        quantity: Ingredient.formatQuantity(
                            whole: ingredient.quantityWhole,
                            fraction: ingredient.fraction
                        ),
                        unit: ingredient.unit.display(forAmount: ingredient.amount),
                        name: ingredient.name,
                        pointSize: 22
                    )
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 0)

            // Optional credit footer.
            if let credit = recipe.credit, !credit.isEmpty {
                Text(credit.uppercased())
                    .font(.tinctaUILabel(11))
                    .tracking(1.2)
                    .foregroundStyle(foreground.opacity(0.7))
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(hex: recipe.backgroundColorHex))
                .matchedGeometryEffect(id: "recipe-card-\(recipe.id)", in: namespace)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
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
