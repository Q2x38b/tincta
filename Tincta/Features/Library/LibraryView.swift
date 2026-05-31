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
    @State private var editorTarget: EditorTarget?
    @State private var shareRecipe: Recipe?
    @State private var importPreview: ImportPreview?
    @State private var scanSource: RecipeImportSource?
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var showSearch = false

    /// Vertical overlap between consecutive cards. Card is now 420pt; overlap
    /// of ~210pt leaves title + 3 ingredient lines visible.
    private let cardOverlap: CGFloat = 210

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
            RecipeEditorView(recipe: target.recipe)
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
        .sheet(isPresented: $showSearch) {
            LibrarySearchView(recipes: recipes) { recipe in
                showSearch = false
                detailRecipe = recipe
            }
        }
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
                // Top spacing so the first card sits BELOW the floating
                // buttons in the safe area, not under them.
                Color.clear.frame(height: 88)

                ForEach(Array(displayedRecipes.enumerated()), id: \.element.id) { index, recipe in
                    Button {
                        detailRecipe = recipe
                    } label: {
                        RecipeCardView(recipe: recipe, namespace: cardNamespace)
                    }
                    .buttonStyle(.plain)
                    // LATER cards stack ON TOP of earlier ones so each title
                    // peeks above the bottom of the previous card.
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
                // Search button — top-left. Indexes by recipe name + ingredient.
                Button {
                    showSearch = true
                } label: {
                    GlassChip(systemImage: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search recipes")
                .padding(.top, 12)
                .padding(.leading, 18)

                Spacer()

                // Native dropdown: glass label expands into the menu on tap.
                Menu {
                    Section {
                        Button {
                            scanSource = .camera
                        } label: { Label("Scan with Camera", systemImage: "camera") }
                        Button {
                            scanSource = .photos
                        } label: { Label("Pick from Photos", systemImage: "photo.on.rectangle") }
                        Button {
                            scanSource = .files
                        } label: { Label("Choose Files", systemImage: "folder") }
                    }
                    Section {
                        Button {
                            showSettings = true
                        } label: { Label("Settings", systemImage: "gearshape") }
                        Button {
                            showAbout = true
                        } label: { Label("About", systemImage: "info.circle") }
                    }
                } label: {
                    GlassChip(systemImage: "ellipsis")
                }
                .menuStyle(.button)
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
