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
                    RecipeDetailRoute(recipeID: id, namespace: cardNamespace)
                case .editor:
                    // Editor lives in a separate worktree; placeholder for now.
                    RecipeEditorPlaceholder()
                }
            }
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
                    // Wired by integration on main.
                }
                .accessibilityLabel("Library menu")
                .padding(.top, 12)
                .padding(.trailing, 18)
            }
            Spacer()
            HStack {
                Spacer()
                GlassButton(systemImage: "plus", tint: Color.tinctaInk) {
                    // Wired by integration on main.
                }
                .accessibilityLabel("New recipe")
                .padding(.bottom, 28)
                .padding(.trailing, 18)
            }
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

/// Stand-in for the real detail screen. Integration on `main` will replace
/// this with the production view from the detail worktree.
struct RecipeDetailRoute: View {
    let recipeID: UUID
    let namespace: Namespace.ID

    @Query private var recipes: [Recipe]

    init(recipeID: UUID, namespace: Namespace.ID) {
        self.recipeID = recipeID
        self.namespace = namespace
        let id = recipeID
        _recipes = Query(filter: #Predicate<Recipe> { $0.id == id })
    }

    var body: some View {
        let recipe = recipes.first
        ZStack {
            Color(hex: recipe?.backgroundColorHex ?? "#1A1A1A").ignoresSafeArea()
            VStack(spacing: 16) {
                Text(recipe?.name.uppercased() ?? "RECIPE")
                    .font(.tinctaDisplay(48))
                    .foregroundStyle(contrastingForeground(forHex: recipe?.backgroundColorHex ?? "#1A1A1A"))
                    .matchedGeometryEffect(id: "recipe-title-\(recipeID)", in: namespace)
                Text("Recipe detail wired by integration.")
                    .font(.tinctaBody(14))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(32)
        }
    }
}

private struct RecipeEditorPlaceholder: View {
    var body: some View {
        ZStack {
            Color.tinctaParchment.ignoresSafeArea()
            Text("Editor wired by integration")
                .font(.tinctaBody(14))
                .foregroundStyle(Color.tinctaInk.opacity(0.5))
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
