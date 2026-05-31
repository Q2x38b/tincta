import SwiftUI
import SwiftData

/// Modal sheet for creating or editing a Recipe. Styled with the recipe's
/// background color and serves as the entry point into the Drink Builder and
/// Color Picker via injected callbacks (those flows live in sibling worktrees).
struct RecipeEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Caller-supplied callbacks for sibling-feature navigation.
    var onEditDrinkLook: (() -> Void)?
    var onChangeColor: (() -> Void)?
    /// Called after a successful delete so parents can pop back to the gallery.
    var onDelete: (() -> Void)?

    @State private var viewModel: RecipeEditorViewModel
    @State private var showDeleteConfirm = false
    @FocusState private var nameFocused: Bool

    init(
        recipe: Recipe?,
        onEditDrinkLook: (() -> Void)? = nil,
        onChangeColor: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: RecipeEditorViewModel(recipe: recipe))
        self.onEditDrinkLook = onEditDrinkLook
        self.onChangeColor = onChangeColor
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
        .preferredColorScheme(foreground == .white ? .dark : .light)
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
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button("CANCEL") { dismiss() }
                .font(.tinctaUILabel(13))
                .tracking(1.4)
                .foregroundStyle(foreground)

            Spacer()

            Button("DONE") {
                viewModel.save(in: modelContext)
                dismiss()
            }
            .font(.tinctaUILabel(13))
            .tracking(1.4)
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
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("DRINK NAME")
            TextField(
                "",
                text: $viewModel.name,
                prompt: Text("DRINK NAME")
                    .font(.tinctaDisplay(34))
                    .foregroundStyle(foreground.opacity(0.35))
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .focused($nameFocused)
            .font(.tinctaDisplay(34))
            .foregroundStyle(foreground)
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(foreground.opacity(0.25))
                    .frame(height: 1)
            }
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("INGREDIENTS")

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
                    Text("ADD INGREDIENT")
                        .font(.tinctaUILabel(13))
                        .tracking(1.2)
                }
                .foregroundStyle(foreground)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Directions

    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("DIRECTIONS")
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
            sectionLabel("DRINK IMAGE")
            Button {
                onEditDrinkLook?()
            } label: {
                HStack(spacing: 14) {
                    DrinkPreviewView(look: viewModel.editingRecipe?.drinkLook)
                        .frame(width: 56, height: 72)
                    Text("EDIT IMAGE")
                        .font(.tinctaUILabel(13))
                        .tracking(1.2)
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
            sectionLabel("RECIPE CREDIT")
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
            onChangeColor?()
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(background)
                    .overlay(
                        Circle().stroke(foreground.opacity(0.4), lineWidth: 1)
                    )
                    .frame(width: 22, height: 22)
                Text("CHANGE BACKGROUND COLOR")
                    .font(.tinctaUILabel(13))
                    .tracking(1.2)
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
            Text("DELETE RECIPE")
                .font(.tinctaUILabel(13))
                .tracking(1.4)
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
            .font(.tinctaUILabel(11))
            .tracking(1.6)
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
