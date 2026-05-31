import SwiftUI
import SwiftData

/// The Library home screen — a vertical stack of overlapping rounded recipe
/// cards rendered against the parchment background. Matches Image 1 of the
/// design mocks.
///
/// Architecture notes:
/// - Persistence reads come in through `@Query` so SwiftData stays the source
///   of truth. The view model only owns ephemeral UI state (search, scroll).
/// - Navigation is driven through a `NavigationPath` over `LibraryRoute` so
///   the integration pass can swap the placeholder detail view for the real
///   one without touching this file.
/// - Cards overlap via a negative-spacing VStack; each card uses
///   `matchedGeometryEffect` so the detail expand animation can be wired
///   on integration.
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]

    @State private var viewModel = LibraryViewModel()
    @State private var path = NavigationPath()
    @Namespace private var cardNamespace

    // Sheet presentation state — owned by the Library since it's the app's home.
    @State private var menuPresented = false
    @State private var editorTarget: EditorTarget?
    @State private var shareRecipe: Recipe?
    @State private var importPreview: ImportPreview?
    @State private var scanSource: RecipeImportSource?
    @State private var showSettings = false
    @State private var showAbout = false

    /// Vertical overlap between consecutive cards. Negative spacing makes
    /// each card slip ~140pt under the next so titles peek through.
    private let cardOverlap: CGFloat = 140

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                Color.tinctaParchment.ignoresSafeArea()

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
            .navigationBarHidden(true)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.isSearchPresented)
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case .detail(let id):
                    RecipeDetailRoute(
                        recipeID: id,
                        namespace: cardNamespace,
                        onEdit: { recipe in editorTarget = .existing(recipe) },
                        onShare: { recipe in shareRecipe = recipe }
                    )
                case .editor:
                    EmptyView()  // editor is presented as a sheet, not pushed
                }
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
                        onShare: { menuPresented = false /* hook for shared library export later */ },
                        onImport: { menuPresented = false /* hook for paste/file picker later */ },
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
                        path.append(LibraryRoute.detail(recipe.id))
                    } label: {
                        RecipeCardView(recipe: recipe, namespace: cardNamespace)
                    }
                    .buttonStyle(.plain)
                    // Newer cards sit on top so overlap reads top-to-bottom.
                    .zIndex(Double(displayedRecipes.count - index))
                }

                // Trailing spacing so the last card doesn't hug the bottom edge.
                Color.clear.frame(height: cardOverlap + 80)
            }
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: "library-scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            // SwiftUI dispatches preference updates on the main actor.
            viewModel.handleScrollOffsetChange(-offset)
        }
    }

    // MARK: - Floating controls

    private var floatingControls: some View {
        VStack {
            HStack {
                Spacer()
                GlassButton(systemImage: "ellipsis", tint: Color.tinctaInk) {
                    menuPresented.toggle()
                }
                .accessibilityLabel("Library menu")
                .padding(.top, 12)
                .padding(.trailing, 18)
            }
            Spacer()
            HStack {
                Spacer()
                GlassButton(systemImage: "plus", tint: Color.tinctaInk) {
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

// MARK: - Scroll offset preference

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Placeholder destinations

/// Navigation destination for a recipe by id. Looks the recipe up in SwiftData
/// and renders the production `RecipeDetailView`, forwarding Edit and Share
/// taps back to the Library so the right sheet can be presented.
struct RecipeDetailRoute: View {
    let recipeID: UUID
    let namespace: Namespace.ID
    let onEdit: (Recipe) -> Void
    let onShare: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var recipes: [Recipe]

    init(recipeID: UUID,
         namespace: Namespace.ID,
         onEdit: @escaping (Recipe) -> Void,
         onShare: @escaping (Recipe) -> Void) {
        self.recipeID = recipeID
        self.namespace = namespace
        self.onEdit = onEdit
        self.onShare = onShare
        let id = recipeID
        _recipes = Query(filter: #Predicate<Recipe> { $0.id == id })
    }

    var body: some View {
        if let recipe = recipes.first {
            RecipeDetailView(
                recipe: recipe,
                onDismiss: { dismiss() },
                onEdit: { onEdit(recipe) },
                onShare: { onShare($0) }
            )
            .navigationBarBackButtonHidden(true)
        } else {
            // Recipe was deleted out from under us — pop.
            Color.tinctaParchment
                .ignoresSafeArea()
                .onAppear { dismiss() }
        }
    }
}

// MARK: - Previews

#Preview("Library") {
    LibraryView()
        .modelContainer(TinctaModelContainer.makePreview())
}

#Preview("Library — search") {
    LibraryView()
        .modelContainer(TinctaModelContainer.makePreview())
}
