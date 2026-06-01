import SwiftUI

/// Sheet for editing one `RecipeSizeDraft` — name, default flag, and the
/// per-ingredient amount overrides. Presented from the editor's SIZES row.
struct SizeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var size: RecipeSizeDraft
    /// Base ingredients on the recipe — used so each amount row can show
    /// the ingredient name and unit alongside the override quantity.
    let ingredients: [IngredientDraft]
    let foreground: Color
    let background: Color
    /// Tapped when the user wants to delete this size from the recipe.
    var onDelete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    nameField
                    defaultToggle
                    amountsList
                    deleteButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle(size.name.isEmpty ? "Size" : size.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }

    // MARK: - Sections

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Size name")
            TextField(
                "",
                text: $size.name,
                prompt: Text("e.g. Double, Pitcher")
                    .foregroundStyle(foreground.opacity(0.45))
            )
            .font(.tinctaBody(17))
            .foregroundStyle(foreground)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(field)
        }
    }

    private var defaultToggle: some View {
        Toggle(isOn: $size.isDefault) {
            Text("Show this size by default")
                .font(.tinctaBody(15))
                .foregroundStyle(foreground)
        }
        .tint(foreground)
    }

    private var amountsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Ingredient amounts")
            if ingredients.isEmpty {
                Text("Add ingredients to the recipe first.")
                    .font(.tinctaBody(14))
                    .foregroundStyle(foreground.opacity(0.55))
            } else {
                // Lazy so rows aren't built unless they're scrolled into view.
                // For long ingredient lists this is the single biggest win.
                LazyVStack(spacing: 8) {
                    ForEach(ingredients) { ing in
                        amountRow(for: ing)
                    }
                }
            }
        }
    }

    private func amountRow(for ingredient: IngredientDraft) -> some View {
        let amountIdx = size.amounts.firstIndex { $0.ingredientID == ingredient.id }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ingredient.name.isEmpty ? "(unnamed)" : ingredient.name)
                    .font(.tinctaUILabel(14))
                    .foregroundStyle(foreground)
                Text(ingredient.unit.display.isEmpty ? "count" : ingredient.unit.display)
                    .font(.tinctaBody(11))
                    .foregroundStyle(foreground.opacity(0.55))
                Spacer()
                if let idx = amountIdx {
                    Text(quantityLabel(amounts: size.amounts[idx]))
                        .font(.tinctaBody(15).monospacedDigit())
                        .foregroundStyle(foreground)
                }
            }

            if let idx = amountIdx {
                // Pure-SwiftUI stepper: two Buttons + a value display. Much
                // cheaper to mount than UIKit's Stepper (which builds an
                // entire UIStepper view per row).
                HStack(spacing: 8) {
                    stepButton(systemImage: "minus") {
                        if size.amounts[idx].quantityWhole > 0 {
                            size.amounts[idx].quantityWhole -= 1
                        }
                    }
                    Text("\(size.amounts[idx].quantityWhole)")
                        .font(.tinctaBody(15).monospacedDigit())
                        .foregroundStyle(foreground)
                        .frame(width: 28)
                    stepButton(systemImage: "plus") {
                        if size.amounts[idx].quantityWhole < 64 {
                            size.amounts[idx].quantityWhole += 1
                        }
                    }

                    // Inline fraction chips — no Menu, no popover.
                    HStack(spacing: 4) {
                        fractionChip(nil, currentIdx: idx)
                        ForEach(Fraction.allCases) { f in
                            fractionChip(f, currentIdx: idx)
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
        .padding(10)
        .background(field)
    }

    @ViewBuilder
    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 28, height: 28)
                .background(field)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fractionChip(_ fraction: Fraction?, currentIdx idx: Int) -> some View {
        let isSelected = size.amounts[idx].fraction == fraction
        Button {
            size.amounts[idx].fraction = fraction
        } label: {
            Text(fraction?.display ?? "—")
                .font(.tinctaBody(13))
                .foregroundStyle(isSelected ? background : foreground)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(isSelected ? foreground : foreground.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }

    private func quantityLabel(amounts: SizeAmountDraft) -> String {
        let whole = amounts.quantityWhole
        switch (whole, amounts.fraction) {
        case (0, .some(let f)):     return f.display
        case (_, .none):            return "\(whole)"
        case (_, .some(let f)):     return "\(whole) \(f.display)"
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete()
            dismiss()
        } label: {
            Text("Delete size")
                .font(.tinctaUILabel(14))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(foreground.opacity(0.10))
                )
        }
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.tinctaUILabel(13))
            .foregroundStyle(foreground.opacity(0.6))
    }

    private var field: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(foreground.opacity(0.10))
    }
}
