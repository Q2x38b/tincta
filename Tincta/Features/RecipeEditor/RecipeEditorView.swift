import SwiftUI
import SwiftData

/// Modal sheet for creating or editing a Recipe. Styled with the recipe's
/// background color and serves as the entry point into the Drink Builder and
/// Color Picker via injected callbacks (those flows live in sibling worktrees).
struct RecipeEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Called after a successful delete so parents can pop back to the gallery.
    var onDelete: (() -> Void)?

    @State private var viewModel: RecipeEditorViewModel
    @State private var showDeleteConfirm = false
    @State private var showColorPicker = false
    @State private var showDrinkBuilder = false
    @State private var editingSizeID: UUID?
    @FocusState private var nameFocused: Bool

    init(
        recipe: Recipe?,
        onDelete: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: RecipeEditorViewModel(recipe: recipe))
        self.onDelete = onDelete
    }

    private var foreground: Color {
        contrastingForeground(forHex: viewModel.backgroundColorHex)
    }

    private var background: Color {
        Color(hex: viewModel.backgroundColorHex)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        nameSection
                        ingredientsSection
                        sizesSection
                        directionsSection
                        drinkImageSection
                        creditSection
                        backgroundColorRow
                        if viewModel.isEditingExisting {
                            deleteButton
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 48)
                }
            }
        }
        // NB: deliberately NOT calling .preferredColorScheme(...) here.
        // Flipping the scene's color scheme on every background change
        // forces UIKit to recreate TextEditor + wheel pickers under the
        // hood, which is what caused the ~10s freeze on color picks.
        .alert("Delete recipe?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                viewModel.delete(in: modelContext)
                onDelete?()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        // Color picker — owned here so the choice writes straight into our
        // own view-model and the editor's background updates live.
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(
                initialHex: viewModel.backgroundColorHex,
                onSelect: { swatch in
                    // Dismiss FIRST, then apply the color on the next runloop.
                    // If we mutate state in the same tick as the dismiss, the
                    // editor body re-renders while the sheet is still animating
                    // away — and on a real device the heavy editor body can
                    // freeze the dismissal animation noticeably.
                    showColorPicker = false
                    DispatchQueue.main.async {
                        viewModel.backgroundColorHex = swatch.hex
                    }
                },
                onCancel: { showColorPicker = false }
            )
        }
        // Drink Builder — also owned here. For brand-new recipes we lazily
        // mint a DrinkLook on the view model so the builder always has one
        // to mutate; it gets persisted with the recipe on Done.
        .sheet(isPresented: $showDrinkBuilder) {
            DrinkBuilderView(
                look: viewModel.ensureDrinkLook(),
                backgroundHex: viewModel.backgroundColorHex
            )
        }
        // Size editor — opens when the user taps a size row.
        .sheet(item: Binding<RecipeSizeDraft?>(
            get: { viewModel.sizes.first(where: { $0.id == editingSizeID }) },
            set: { _ in editingSizeID = nil }
        )) { size in
            SizeEditorSheet(
                size: size,
                ingredients: viewModel.ingredients,
                foreground: foreground,
                background: background,
                onDelete: {
                    viewModel.removeSize(id: size.id)
                }
            )
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.tinctaUILabel(15))
                .foregroundStyle(foreground)

            Spacer()

            Button("Done") {
                viewModel.save(in: modelContext)
                dismiss()
            }
            .font(.tinctaUILabel(15))
            .foregroundStyle(foreground)
            .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1.0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Drink name

    private var nameSection: some View {
        TextField(
            "",
            text: $viewModel.name,
            prompt: Text("Drink name")
                .font(.tinctaDisplay(22))
                .foregroundStyle(foreground.opacity(0.35))
        )
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .focused($nameFocused)
        .font(.tinctaDisplay(22))
        .foregroundStyle(foreground)
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Ingredients")

            if viewModel.ingredients.isEmpty {
                Text("No ingredients yet.")
                    .font(.tinctaBody(15))
                    .foregroundStyle(foreground.opacity(0.55))
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.ingredients) { draft in
                        if let binding = viewModel.binding(for: draft.id) {
                            IngredientRow(
                                draft: binding,
                                isExpanded: viewModel.expandedIngredientID == draft.id,
                                foreground: foreground,
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.toggleExpand(draft.id)
                                    }
                                }
                            )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    if let idx = viewModel.ingredients.firstIndex(where: { $0.id == draft.id }) {
                                        viewModel.ingredients.remove(at: idx)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            Divider()
                                .background(foreground.opacity(0.2))
                        }
                    }
                    .onMove { source, destination in
                        viewModel.moveIngredients(from: source, to: destination)
                    }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.addIngredient()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add ingredient")
                        .font(.tinctaUILabel(14))
                }
                .foregroundStyle(foreground)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Sizes

    private var sizesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Sizes")
                Spacer()
                Menu {
                    Button("Single (1×)") {
                        viewModel.addSize(name: "Single", multiplier: 1.0)
                        editingSizeID = viewModel.sizes.last?.id
                    }
                    Button("Double (2×)") {
                        viewModel.addSize(name: "Double", multiplier: 2.0)
                        editingSizeID = viewModel.sizes.last?.id
                    }
                    Button("Pitcher (8×)") {
                        viewModel.addSize(name: "Pitcher", multiplier: 8.0)
                        editingSizeID = viewModel.sizes.last?.id
                    }
                    Divider()
                    Button("Custom…") {
                        viewModel.addSize(name: "New Size", multiplier: 1.0)
                        editingSizeID = viewModel.sizes.last?.id
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.tinctaUILabel(13))
                        .foregroundStyle(foreground)
                }
            }

            if viewModel.sizes.isEmpty {
                Text("Optional. Add named sizes — e.g. Double or Pitcher — each with their own ingredient amounts.")
                    .font(.tinctaBody(13))
                    .foregroundStyle(foreground.opacity(0.55))
                    .padding(.top, 2)
            } else {
                VStack(spacing: 6) {
                    ForEach(viewModel.sizes) { size in
                        Button {
                            // Keep amount slots in sync with the current
                            // ingredient list before opening the editor.
                            viewModel.syncSizeAmountsToIngredients()
                            editingSizeID = size.id
                        } label: {
                            sizeRow(size)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sizeRow(_ size: RecipeSizeDraft) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(size.name.isEmpty ? "Untitled" : size.name)
                    .font(.tinctaBody(15))
                    .foregroundStyle(foreground)
                if size.isDefault {
                    Text("Default")
                        .font(.tinctaUILabel(11))
                        .foregroundStyle(foreground.opacity(0.55))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(foreground.opacity(0.55))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(foreground.opacity(0.08))
        )
    }

    // MARK: - Directions

    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Directions")
            TextField(
                "",
                text: $viewModel.directions,
                prompt: Text("How is this drink made?")
                    .font(.tinctaBody(16))
                    .foregroundStyle(foreground.opacity(0.45)),
                axis: .vertical
            )
            .lineLimit(3...10)
            .font(.tinctaBody(16))
            .foregroundStyle(foreground)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(foreground.opacity(0.08))
            )
        }
    }

    // MARK: - Drink image / look

    private var drinkImageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Drink image")
            Button {
                showDrinkBuilder = true
            } label: {
                HStack(spacing: 14) {
                    DrinkPreviewView(look: viewModel.workingDrinkLook ?? viewModel.editingRecipe?.drinkLook)
                        .frame(width: 56, height: 72)
                    Text("Edit image")
                        .font(.tinctaUILabel(14))
                        .foregroundStyle(foreground)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(foreground.opacity(0.55))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(foreground.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Credit

    private var creditSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Recipe credit")
            TextField(
                "",
                text: $viewModel.credit,
                prompt: Text("Who created this?")
                    .font(.tinctaBody(16))
                    .foregroundStyle(foreground.opacity(0.45))
            )
            .autocorrectionDisabled()
            .font(.tinctaBody(16))
            .foregroundStyle(foreground)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(foreground.opacity(0.08))
            )
        }
    }

    // MARK: - Color row

    private var backgroundColorRow: some View {
        Button {
            showColorPicker = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(background)
                    .overlay(
                        Circle().stroke(foreground.opacity(0.4), lineWidth: 1)
                    )
                    .frame(width: 22, height: 22)
                Text("Change background color")
                    .font(.tinctaUILabel(14))
                    .foregroundStyle(foreground)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(foreground.opacity(0.55))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(foreground.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Text("Delete recipe")
                .font(.tinctaUILabel(14))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(foreground.opacity(0.10))
                )
        }
        .padding(.top, 10)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.tinctaUILabel(13))
            .foregroundStyle(foreground.opacity(0.65))
    }
}

// MARK: - Previews

#Preview("New recipe") {
    RecipeEditorView(recipe: nil)
        .modelContainer(TinctaModelContainer.makePreview())
}

#Preview("Edit existing") {
    let container = TinctaModelContainer.makePreview()
    let descriptor = FetchDescriptor<Recipe>()
    let recipe = try? container.mainContext.fetch(descriptor).first
    return RecipeEditorView(recipe: recipe)
        .modelContainer(container)
}
