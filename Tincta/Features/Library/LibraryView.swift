import SwiftUI
import SwiftData

/// The Library home screen — a vertical stack of overlapping rounded recipe
/// cards rendered against a near-black background, matching the design mocks.
///
/// Architecture notes:
/// - Persistence reads come in through `@Query` so SwiftData stays the source
///   of truth. The view model only owns ephemeral UI state (search, scroll).
/// - Recipe detail is presented as a system bottom-sheet (with swipe-down
///   dismiss), not pushed onto a NavigationStack — feels card-native.
/// - Cards overlap via a negative-spacing VStack; later cards stack ON TOP
///   of earlier ones, covering their bottom edge so titles read top-to-bottom.
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]

    @State private var viewModel = LibraryViewModel()
    @Namespace private var cardNamespace

    // Sheet/overlay presentation state — owned by the Library since it's home.
    @State private var detailRecipe: Recipe?
    @State private var menuPresented = false
    @State private var editorTarget: EditorTarget?
    @State private var shareRecipe: Recipe?
    @State private var importPreview: ImportPreview?
    @State private var scanSource: RecipeImportSource?
    @State private var showSettings = false
    @State private var showAbout = false

    /// Vertical overlap between consecutive cards. Each card is ~520pt tall;
    /// overlapping by ~250pt leaves the title + 4 ingredient lines visible
    /// before the next card stacks on top.
    private let cardOverlap: CGFloat = 250

    var body: some View {
        ZStack(alignment: .top) {
            Color.tinctaInk.ignoresSafeArea()

            cardStack
                .overlay(alignment: .top) {
                    if viewModel.isSearchPresented {
                        LibrarySearchOverlay(
                            searchText: $viewModel.searchText,
                            onCancel: { withAnimation(.spring) { viewModel.dismissSearch() } }
                        )
                        .padding(.top, 8)
                        .zIndex(2)
                    }
                }

            floatingControls
                .zIndex(3)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.isSearchPresented)
        // Recipe detail as a card sheet so swipe-down dismisses it like a stack
        // of cards instead of a full-screen navigation push.
        .sheet(item: $detailRecipe) { recipe in
            RecipeDetailSheet(
                recipe: recipe,
                onEdit: { editorTarget = .existing(recipe) },
                onShare: { shareRecipe = $0 }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editorTarget) { target in
            EditorSheet(target: target)
        }
        .sheet(item: $shareRecipe) { recipe in
            RecipeShareSheet(recipe: recipe)
        }
        .sheet(item: $importPreview) { preview in
            ImportPreviewView(transfer: preview.transfer)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showAbout) { AboutView() }
        .sheet(item: $scanSource) { source in
            RecipeImportFlow(source: source)
        }
        .overlay(alignment: .topTrailing) {
            if menuPresented {
                MenuDropdownView(
                    isPresented: $menuPresented,
                    onSettings: { menuPresented = false; showSettings = true },
                    onShare: { menuPresented = false },
                    onImport: { menuPresented = false },
                    onAbout: { menuPresented = false; showAbout = true },
                    onScan: { source in
                        menuPresented = false
                        scanSource = source
                    }
                )
                .padding(.top, 76)
                .padding(.trailing, 18)
                .transition(.scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: menuPresented)
        .handleTinctaImportLink(into: modelContext, presented: $importPreview)
    }

    // MARK: - Card stack

    private var displayedRecipes: [Recipe] {
        viewModel.filtered(recipes)
    }

    private var cardStack: some View {
        ScrollView {
            // Track scroll offset for the pull-down-to-search gesture.
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: -proxy.frame(in: .named("library-scroll")).minY
                    )
            }
            .frame(height: 0)

            LazyVStack(spacing: -cardOverlap) {
                // Top spacing for safe area + status bar.
                Color.clear.frame(height: 24)

                ForEach(Array(displayedRecipes.enumerated()), id: \.element.id) { index, recipe in
                    Button {
                        detailRecipe = recipe
                    } label: {
                        RecipeCardView(recipe: recipe, namespace: cardNamespace)
                    }
                    .buttonStyle(.plain)
                    // LATER cards stack ON TOP of earlier ones — that's why the
                    // title-then-bleed-into-next-card pattern reads correctly.
                    .zIndex(Double(index))
                }

                // Trailing spacing so the last card doesn't hug the bottom edge.
                Color.clear.frame(height: cardOverlap + 80)
            }
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: "library-scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            viewModel.handleScrollOffsetChange(-offset)
        }
    }

    // MARK: - Floating controls

    private var floatingControls: some View {
        VStack {
            HStack {
                Spacer()
                GlassButton(systemImage: "ellipsis") {
                    menuPresented.toggle()
                }
                .accessibilityLabel("Library menu")
                .padding(.top, 12)
                .padding(.trailing, 18)
            }
            Spacer()
            HStack {
                Spacer()
                GlassButton(systemImage: "plus") {
                    editorTarget = .new
                }
                .accessibilityLabel("New recipe")
                .padding(.bottom, 28)
                .padding(.trailing, 18)
            }
        }
    }
}

// MARK: - Editor sheet plumbing

/// What the editor is editing — either an existing recipe or a freshly-created
/// blank one. Identifiable so SwiftUI's `.sheet(item:)` knows when to re-present.
enum EditorTarget: Identifiable {
    case new
    case existing(Recipe)

    var id: UUID {
        switch self {
        case .new:                      return UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        case .existing(let recipe):     return recipe.id
        }
    }

    var recipe: Recipe? {
        if case .existing(let r) = self { return r }
        return nil
    }
}

/// Wraps `RecipeEditorView` to also manage Drink Builder and Color Picker
/// sheets that the editor delegates to via its callbacks.
struct EditorSheet: View {
    @Environment(\.modelContext) private var context
    let target: EditorTarget

    @State private var showBuilder = false
    @State private var showColorPicker = false
    @State private var workingDrinkLook: DrinkLook?

    var body: some View {
        RecipeEditorView(
            recipe: target.recipe,
            onEditDrinkLook: {
                workingDrinkLook = target.recipe?.drinkLook
                showBuilder = true
            },
            onChangeColor: { showColorPicker = true }
        )
        .sheet(isPresented: $showBuilder) {
            if let look = workingDrinkLook {
                DrinkBuilderView(look: look,
                                 backgroundHex: target.recipe?.backgroundColorHex ?? "#3F5C5F")
            } else {
                Text("Save the recipe first to edit its drink image.")
                    .padding()
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(
                initialHex: target.recipe?.backgroundColorHex ?? TinctaPalette.sage.hex,
                onSelect: { swatch in
                    target.recipe?.backgroundColorHex = swatch.hex
                    try? context.save()
                    showColorPicker = false
                },
                onCancel: { showColorPicker = false }
            )
        }
    }
}

// MARK: - Recipe detail sheet

/// Adapter that renders `RecipeDetailView` inside a sheet, wiring the chevron
/// dismiss to the sheet's own `dismiss` action.
struct RecipeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let onEdit: () -> Void
    let onShare: (Recipe) -> Void

    var body: some View {
        RecipeDetailView(
            recipe: recipe,
            onDismiss: { dismiss() },
            onEdit: onEdit,
            onShare: onShare
        )
    }
}

// MARK: - Scroll offset preference

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Previews

#Preview("Library") {
    LibraryView()
        .modelContainer(TinctaModelContainer.makePreview())
}
