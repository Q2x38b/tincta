import SwiftUI
import SwiftData

// MARK: - RecipeDetailView

/// Full-screen recipe view (Image 2 of the design mocks).
///
/// Layout, top → bottom:
///   1. Top bar:    drink name in serif display caps + EDIT (top-right, no-op
///                  placeholder in this worktree).
///   2. Ingredient block: each `orderedIngredients` rendered with
///                  `IngredientLineText`, scaled by the view model.
///   3. Drink graphic: a centered placeholder (`DrinkLookPlaceholderView`) —
///                  integration swaps in the real vector renderer.
///   4. Directions block: numbered steps from `DirectionsRenderer`.
///   5. Bottom safe-area glass bar: dismiss chevron, OZ|ML segmented control,
///                  QTY stepper, share button.
struct RecipeDetailView: View {

    let recipe: Recipe

    /// Tapped when the user hits the down-chevron in the bottom bar.
    var onDismiss: () -> Void

    /// Tapped when the user hits the EDIT button in the top bar.
    var onEdit: () -> Void

    /// Tapped when the user hits the share button in the bottom bar.
    /// Integration wires this up to `RecipeShareSheet`.
    var onShare: (Recipe) -> Void

    @State private var model: DetailViewModel

    init(
        recipe: Recipe,
        onDismiss: @escaping () -> Void = {},
        onEdit: @escaping () -> Void = {},
        onShare: @escaping (Recipe) -> Void = { _ in }
    ) {
        self.recipe = recipe
        self.onDismiss = onDismiss
        self.onEdit = onEdit
        self.onShare = onShare
        _model = State(initialValue: DetailViewModel(
            displayUnit: DetailViewModel.defaultDisplayUnit(for: recipe),
            selectedSizeID: recipe.defaultSize?.id
        ))
    }

    /// Resolves the currently-selected `RecipeSize` (or nil = base amounts).
    private var selectedSize: RecipeSize? {
        guard let id = model.selectedSizeID else { return nil }
        return recipe.orderedSizes.first { $0.id == id }
    }

    private var foreground: Color {
        contrastingForeground(forHex: recipe.backgroundColorHex)
    }

    var body: some View {
        ZStack {
            Color(hex: recipe.backgroundColorHex)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    ingredientsBlock
                    drinkGraphic
                    directionsBlock
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 28)
                // Bumped from 8 → 28 so the title sits clear of the sheet's
                // drag indicator + status-bar inset, rather than hugging the
                // top edge of the presentation.
                .padding(.top, 28)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(foreground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Text(recipe.name)
                .font(.tinctaDisplay(26))
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 12)

            Button(action: onEdit) {
                Text("Edit")
                    .font(.tinctaUILabel(14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule()
                            .strokeBorder(foreground.opacity(0.55), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit recipe")
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    // MARK: - Ingredients

    private var ingredientsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients")
                .font(.tinctaUILabel(13))
                .opacity(0.7)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(recipe.orderedIngredients, id: \.id) { ingredient in
                    let line = model.scaledLine(for: ingredient, size: selectedSize)
                    IngredientLineText(
                        quantity: line.quantity,
                        unit: line.unit,
                        name: line.name,
                        pointSize: 22
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: line))
                }
            }

            // Size picker — only shown if the recipe has named variations.
            if !recipe.orderedSizes.isEmpty {
                sizePickerStrip
                    .padding(.top, 4)
            }
        }
    }

    private var sizePickerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(recipe.orderedSizes) { size in
                    sizeChip(size)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func sizeChip(_ size: RecipeSize) -> some View {
        let isSelected = model.selectedSizeID == size.id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                model.selectedSizeID = size.id
            }
        } label: {
            Text(size.name)
                .font(.tinctaUILabel(13))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected
                                 ? Color(hex: recipe.backgroundColorHex)
                                 : foreground)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? foreground : foreground.opacity(0.18))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Size: \(size.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityLabel(for line: (quantity: String, unit: String, name: String)) -> String {
        if line.unit.isEmpty {
            return "\(line.quantity) \(line.name)"
        }
        return "\(line.quantity) \(line.unit) \(line.name)"
    }

    // MARK: - Drink graphic placeholder

    private var drinkGraphic: some View {
        HStack {
            Spacer()
            DrinkPreviewView(look: recipe.drinkLook)
                .frame(width: 200, height: 240)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Directions

    private var directionsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Directions")
                .font(.tinctaUILabel(13))
                .opacity(0.7)

            let steps = DirectionsRenderer.render(recipe.directions)
            if steps.isEmpty {
                Text("No directions yet.")
                    .font(.tinctaBody(15))
                    .opacity(0.7)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(steps) { step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(step.index).")
                                .font(.tinctaBody(15).weight(.semibold))
                                .frame(width: 20, alignment: .trailing)
                            Text(step.step)
                                .font(.tinctaBody(15))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            if let credit = recipe.credit, !credit.isEmpty {
                Text(credit)
                    .font(.tinctaBody(13).italic())
                    .opacity(0.65)
                    .padding(.top, 12)
            }
        }
    }

    // MARK: - Bottom glass bar

    private var bottomBar: some View {
        // Just the buttons, no glass capsule — they sit on the recipe's own
        // background color and read as native controls.
        HStack(spacing: 14) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .frame(minWidth: 44, minHeight: 44)

            UnitToggle(selection: $model.displayUnit, foreground: foreground)

            QuantityStepper(value: $model.quantityMultiplier, foreground: foreground)

            Spacer(minLength: 0)

            Button {
                onShare(recipe)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share recipe")
            .frame(minWidth: 44, minHeight: 44)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - UnitToggle (OZ | ML)

private struct UnitToggle: View {
    @Binding var selection: Unit
    let foreground: Color

    var body: some View {
        HStack(spacing: 0) {
            cell(.oz, label: "OZ")
            cell(.ml, label: "ML")
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(foreground.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Display unit")
        .accessibilityValue(selection == .ml ? "Milliliters" : "Ounces")
    }

    private func cell(_ unit: Unit, label: String) -> some View {
        let selected = selection == unit
        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                selection = unit
            }
        } label: {
            Text(label)
                .font(.tinctaUILabel(12))
                .tracking(1.4)
                .frame(width: 38, height: 30)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? foreground.opacity(0.9) : .clear)
                )
                .foregroundStyle(selected ? invertedForeground : foreground)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// On a dark `foreground` the inverted fill is white; on white it's dark.
    private var invertedForeground: Color {
        // foreground here is either near-white or near-#1F1F1F.
        // We just want the opposite for readable text on the pill.
        foreground == .white ? Color(hex: "#1F1F1F") : .white
    }
}

// MARK: - QuantityStepper

private struct QuantityStepper: View {
    @Binding var value: Int
    let foreground: Color
    let range: ClosedRange<Int> = 1...12

    var body: some View {
        HStack(spacing: 0) {
            stepperButton(systemImage: "minus", enabled: value > range.lowerBound) {
                if value > range.lowerBound { value -= 1 }
            }
            .accessibilityLabel("Decrease quantity")

            VStack(spacing: 0) {
                Text("\(value)×")
                    .font(.tinctaUILabel(13))
                    .monospacedDigit()
                Text("QTY")
                    .font(.tinctaUILabel(9))
                    .tracking(1.2)
                    .opacity(0.7)
            }
            .frame(width: 44, height: 36)

            stepperButton(systemImage: "plus", enabled: value < range.upperBound) {
                if value < range.upperBound { value += 1 }
            }
            .accessibilityLabel("Increase quantity")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(foreground.opacity(0.12))
        )
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(value) drinks")
    }

    private func stepperButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .frame(minWidth: 32, minHeight: 32)
    }
}

// MARK: - Preview

#Preview("Old Fashioned") {
    let container = TinctaModelContainer.makePreview()
    let recipe = (try? container.mainContext.fetch(FetchDescriptor<Recipe>()))?
        .first(where: { $0.name == "Old Fashioned" })
        ?? Recipe(name: "Old Fashioned", backgroundColorHex: "#A6522D")
    return RecipeDetailView(recipe: recipe)
        .modelContainer(container)
}

#Preview("Tom Collins") {
    let container = TinctaModelContainer.makePreview()
    let recipe = (try? container.mainContext.fetch(FetchDescriptor<Recipe>()))?
        .first(where: { $0.name == "Tom Collins" })
        ?? Recipe(name: "Tom Collins", backgroundColorHex: "#D4A24C")
    return RecipeDetailView(recipe: recipe)
        .modelContainer(container)
}

#Preview("Mint Julep") {
    let container = TinctaModelContainer.makePreview()
    let recipe = (try? container.mainContext.fetch(FetchDescriptor<Recipe>()))?
        .first(where: { $0.name == "Mint Julep" })
        ?? Recipe(name: "Mint Julep", backgroundColorHex: "#7C8B6A")
    return RecipeDetailView(recipe: recipe)
        .modelContainer(container)
}
