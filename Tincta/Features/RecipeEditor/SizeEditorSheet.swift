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
            sectionLabel("SIZE NAME")
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
            sectionLabel("INGREDIENT AMOUNTS")
            if ingredients.isEmpty {
                Text("Add ingredients to the recipe first.")
                    .font(.tinctaBody(14))
                    .foregroundStyle(foreground.opacity(0.55))
            } else {
                VStack(spacing: 8) {
                    ForEach(ingredients) { ing in
                        amountRow(for: ing)
                    }
                }
            }
        }
    }

    private func amountRow(for ingredient: IngredientDraft) -> some View {
        let amountIdx = size.amounts.firstIndex { $0.ingredientID == ingredient.id }
        return HStack(spacing: 10) {
            // Ingredient name + unit
            VStack(alignment: .leading, spacing: 1) {
                Text(ingredient.name.isEmpty ? "(unnamed)" : ingredient.name.uppercased())
                    .font(.tinctaUILabel(12))
                    .tracking(1.0)
                    .foregroundStyle(foreground)
                Text(ingredient.unit.display.isEmpty ? "count" : ingredient.unit.display)
                    .font(.tinctaBody(11))
                    .foregroundStyle(foreground.opacity(0.55))
            }
            Spacer()

            if let idx = amountIdx {
                // Whole-number stepper
                Stepper(value: Binding(
                    get: { size.amounts[idx].quantityWhole },
                    set: { size.amounts[idx].quantityWhole = max(0, $0) }
                ), in: 0...64) {
                    Text("\(size.amounts[idx].quantityWhole)")
                        .font(.tinctaBody(15).monospacedDigit())
                        .foregroundStyle(foreground)
                        .frame(minWidth: 22, alignment: .trailing)
                }
                .labelsHidden()

                // Fraction picker (none, ⅛, ¼, ⅓, ½, ⅔, ¾)
                Menu {
                    Button("none") { size.amounts[idx].fraction = nil }
                    ForEach(Fraction.allCases) { f in
                        Button(f.display) { size.amounts[idx].fraction = f }
                    }
                } label: {
                    Text(size.amounts[idx].fraction?.display ?? "—")
                        .font(.tinctaBody(15))
                        .foregroundStyle(foreground)
                        .frame(width: 36, height: 28)
                        .background(field)
                }
            }
        }
        .padding(10)
        .background(field)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete()
            dismiss()
        } label: {
            Text("DELETE SIZE")
                .font(.tinctaUILabel(13))
                .tracking(1.3)
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
            .font(.tinctaUILabel(10))
            .tracking(1.4)
            .foregroundStyle(foreground.opacity(0.6))
    }

    private var field: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(foreground.opacity(0.10))
    }
}
