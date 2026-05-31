import SwiftUI
import SwiftData

/// Renderable, image-export-friendly recipe card. Mirrors the visual language
/// of the in-app card but is self-contained so the Sharing feature can render
/// it via `ImageRenderer` without depending on the Library feature's view.
struct ShareableRecipeCard: View {
    let recipe: Recipe
    /// Fixed render width; the height grows with the directions block.
    let width: CGFloat

    init(recipe: Recipe, width: CGFloat = 1080) {
        self.recipe = recipe
        self.width = width
    }

    private var background: Color { Color(hex: recipe.backgroundColorHex) }
    private var foreground: Color { contrastingForeground(forHex: recipe.backgroundColorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            header
            ingredientsSection
            if !recipe.directions.isEmpty {
                directionsSection
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, width * 0.075)
        .padding(.vertical, width * 0.075)
        .frame(width: width, alignment: .topLeading)
        .background(background)
        .foregroundStyle(foreground)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TINCTA")
                .font(.tinctaUILabel(width * 0.018))
                .tracking(4)
                .opacity(0.55)

            Text(recipe.name.uppercased())
                .font(.tinctaDisplay(width * 0.085))
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            if let credit = recipe.credit, !credit.isEmpty {
                Text(credit.uppercased())
                    .font(.tinctaUILabel(width * 0.018))
                    .tracking(3)
                    .opacity(0.6)
            }
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("INGREDIENTS")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(recipe.orderedIngredients) { ingredient in
                    IngredientLineText(
                        quantity: Ingredient.formatQuantity(
                            whole: ingredient.quantityWhole,
                            fraction: ingredient.fraction
                        ),
                        unit: ingredient.unit.display(forAmount: ingredient.amount),
                        name: ingredient.name,
                        pointSize: width * 0.038
                    )
                    .foregroundStyle(foreground)
                }
            }
        }
    }

    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("DIRECTIONS")
            Text(recipe.directions)
                .font(.tinctaBody(width * 0.028))
                .lineSpacing(width * 0.008)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("tincta.app")
                .font(.tinctaUILabel(width * 0.018))
                .tracking(3)
                .opacity(0.55)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.tinctaUILabel(width * 0.02))
            .tracking(2.5)
            .opacity(0.6)
    }
}

// MARK: - Preview

private struct ShareableRecipeCardPreviewHost: View {
    let container: ModelContainer
    @Query private var recipes: [Recipe]

    init(container: ModelContainer) {
        self.container = container
    }

    var body: some View {
        let recipe = recipes.first ?? Recipe(name: "Sample", backgroundColorHex: "#C66A28")
        ScrollView {
            ShareableRecipeCard(recipe: recipe, width: 360)
        }
    }
}

#Preview("Shareable Card") {
    let container = TinctaModelContainer.makePreview()
    return ShareableRecipeCardPreviewHost(container: container)
        .modelContainer(container)
}
