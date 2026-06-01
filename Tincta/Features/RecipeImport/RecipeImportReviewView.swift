import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// The "preview before save" stage of the OCR flow. Lists every parsed recipe
/// as an expandable card so the user can correct OCR mistakes, toggle which
/// ones to keep, and pick a background color before tapping Save.
struct RecipeImportReviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: RecipeImportViewModel

    @State private var colorPickerTarget: RecipeDraft?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(viewModel.drafts) { draft in
                        @Bindable var draft = draft
                        DraftCard(draft: draft) {
                            colorPickerTarget = draft
                        }
                    }

                    if viewModel.drafts.isEmpty {
                        Text("No recipes recognised.")
                            .font(.tinctaBody(15))
                            .foregroundStyle(.secondary)
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .background(Color.tinctaParchment.ignoresSafeArea())
            .navigationTitle("Review Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save \(includedCount)") {
                        viewModel.save(in: context)
                        dismiss()
                    }
                    .bold()
                    .disabled(includedCount == 0)
                }
            }
            .sheet(item: $colorPickerTarget) { draft in
                ColorPickerView(
                    initialHex: draft.backgroundColorHex,
                    onSelect: { swatch in
                        draft.backgroundColorHex = swatch.hex
                        colorPickerTarget = nil
                    },
                    onCancel: { colorPickerTarget = nil }
                )
            }
        }
    }

    private var includedCount: Int {
        viewModel.drafts.filter(\.isIncluded).count
    }
}

// MARK: - DraftCard

private struct DraftCard: View {
    @Bindable var draft: RecipeDraft
    let onChangeColor: () -> Void

    @State private var isExpanded = true

    var body: some View {
        let fg = contrastingForeground(forHex: draft.backgroundColorHex)
        VStack(alignment: .leading, spacing: 14) {
            header(fg: fg)
            if let notice = draft.notice {
                noticeBanner(notice, fg: fg)
            }
            if isExpanded {
                Divider().background(fg.opacity(0.25))
                nameField(fg: fg)
                ingredientsSection(fg: fg)
                directionsSection(fg: fg)
                colorRow(fg: fg)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: draft.backgroundColorHex))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(fg.opacity(0.18), lineWidth: 0.8)
        )
        .opacity(draft.isIncluded ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    private func header(fg: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Toggle("", isOn: $draft.isIncluded)
                .toggleStyle(.switch)
                .tint(fg.opacity(0.8))
                .labelsHidden()
                .scaleEffect(0.8)
                .frame(width: 50)

            Text(draft.name)
                .font(.tinctaDisplay(20))
                .foregroundStyle(fg)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(fg.opacity(0.7))
                    .frame(width: 28, height: 28)
            }
        }
    }

    private func noticeBanner(_ text: String, fg: Color) -> some View {
        Text(text)
            .font(.tinctaBody(12))
            .foregroundStyle(fg.opacity(0.85))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fg.opacity(0.12))
            )
    }

    private func nameField(fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Name", fg: fg)
            TextField("Drink name", text: $draft.name)
                .font(.tinctaBody(16))
                .foregroundStyle(fg)
                .textFieldStyle(.plain)
                .padding(10)
                .background(field(fg: fg))
        }
    }

    private func ingredientsSection(fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionLabel("Ingredients", fg: fg)
                Spacer()
                Button {
                    draft.addIngredient()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.tinctaUILabel(13))
                        .foregroundStyle(fg)
                }
            }
            VStack(spacing: 8) {
                ForEach(Array(draft.ingredients.enumerated()), id: \.element.id) { idx, ing in
                    @Bindable var ing = ing
                    DraftIngredientRow(ing: ing, fg: fg) {
                        draft.ingredients.removeAll { $0.id == ing.id }
                    }
                }
            }
        }
    }

    private func directionsSection(fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Directions", fg: fg)
            TextEditor(text: $draft.directions)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100, maxHeight: 200)
                .font(.tinctaBody(15))
                .foregroundStyle(fg)
                .padding(8)
                .background(field(fg: fg))
        }
    }

    private func colorRow(fg: Color) -> some View {
        Button(action: onChangeColor) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: draft.backgroundColorHex))
                    .overlay(Circle().stroke(fg.opacity(0.4), lineWidth: 1))
                    .frame(width: 18, height: 18)
                Text("Card color")
                    .font(.tinctaUILabel(13))
                    .foregroundStyle(fg)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(fg.opacity(0.5))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(field(fg: fg))
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String, fg: Color) -> some View {
        Text(text)
            .font(.tinctaUILabel(13))
            .foregroundStyle(fg.opacity(0.6))
    }

    private func field(fg: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fg.opacity(0.10))
    }
}

// MARK: - DraftIngredientRow

private struct DraftIngredientRow: View {
    @Bindable var ing: IngredientLineDraft
    let fg: Color
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("0", value: $ing.quantityWhole, format: .number)
                .keyboardType(.numberPad)
                .frame(width: 44)
                .multilineTextAlignment(.center)
                .font(.tinctaBody(15))
                .foregroundStyle(fg)
                .padding(.vertical, 6)
                .background(field)

            Menu {
                Button("none") { ing.fraction = nil }
                ForEach(Fraction.allCases) { f in
                    Button(f.display) { ing.fraction = f }
                }
            } label: {
                Text(ing.fraction?.display ?? "—")
                    .font(.tinctaBody(15))
                    .foregroundStyle(fg)
                    .frame(width: 36, height: 28)
                    .background(field)
            }

            Menu {
                ForEach(Unit.allCases) { u in
                    Button(u.display.isEmpty ? "(count)" : u.display) { ing.unit = u }
                }
            } label: {
                Text(ing.unit.display.isEmpty ? "ct" : ing.unit.display)
                    .font(.tinctaBody(13))
                    .foregroundStyle(fg)
                    .frame(width: 50, height: 28)
                    .background(field)
            }

            TextField("Ingredient", text: $ing.name)
                .font(.tinctaBody(15))
                .foregroundStyle(fg)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(field)

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(fg.opacity(0.65))
            }
            .buttonStyle(.plain)
        }
    }

    private var field: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(fg.opacity(0.10))
    }
}

#Preview {
    let vm = RecipeImportViewModel()
    vm.drafts = [
        RecipeDraft(name: "Old Fashioned",
                    directions: "Stir bourbon, syrup, bitters with ice.\nStrain into rocks glass with one large cube.\nGarnish with orange peel.",
                    credit: "",
                    backgroundColorHex: TinctaPalette.rust.hex,
                    ingredients: [
                        IngredientLineDraft(quantityWhole: 2, fraction: nil, unit: .oz, name: "Bourbon"),
                        IngredientLineDraft(quantityWhole: 0, fraction: .quarter, unit: .oz, name: "Simple Syrup (1:1)"),
                        IngredientLineDraft(quantityWhole: 1, fraction: nil, unit: .dash, name: "Angostura Bitters"),
                    ]),
        RecipeDraft(name: "Tom Collins",
                    directions: "Shake gin, syrup, lemon juice.\nStrain into Collins glass.\nTop with soda.",
                    credit: "",
                    backgroundColorHex: TinctaPalette.gold.hex,
                    ingredients: [
                        IngredientLineDraft(quantityWhole: 2, fraction: nil, unit: .oz, name: "Gin"),
                        IngredientLineDraft(quantityWhole: 0, fraction: .threeQuarters, unit: .oz, name: "Lemon Juice"),
                    ]),
    ]
    vm.stage = .ready
    return RecipeImportReviewView(viewModel: vm)
        .modelContainer(TinctaModelContainer.makePreview())
}
