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
    @State private var importPreview: ImportPreview?
    @State private var scanSource: RecipeImportSource?
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var showSearch = false

    /// Vertical overlap between consecutive cards. Cards now have a
    /// minHeight of 280pt and grow with ingredient count. Overlap of ~150pt
    /// leaves the title + ~3 ingredient lines visible above the next card's
    /// bleed — for cards with many ingredients, more rows show through.
    private let cardOverlap: CGFloat = 150

    var body: some View {
        ZStack(alignment: .top) {
            Color.tinctaInk.ignoresSafeArea()

            cardStack
                .overlay(alignment: .top) {
                    pullSearchHint
                        .padding(.top, 70)
                        .allowsHitTesting(false)
                        .zIndex(2)
                }

            floatingControls
                .zIndex(3)
        }
        // Watch the trigger flag set by the view-model when the user
        // releases an overscroll past the threshold. We open the search
        // sheet and clear the flag so the next pull can fire again.
        .onChange(of: viewModel.shouldOpenSearch) { _, newValue in
            if newValue {
                viewModel.clearOpenSearchTrigger()
                showSearch = true
            }
        }
        // Recipe detail as a card sheet so swipe-down dismisses it like a stack
        // of cards instead of a full-screen navigation push.
        .sheet(item: $detailRecipe) { recipe in
            RecipeDetailSheet(recipe: recipe)
            // Hero zoom — the system matches this id against the source on
            // the card and expands OUT OF the card's frame on present, and
            // shrinks BACK INTO it on dismiss. Symmetric, no separate
            // "float-back" animation.
            .navigationTransition(.zoom(sourceID: recipe.id, in: cardNamespace))
            // Match the card's corner radius + background so the zoom reads
            // as the card itself growing rather than a generic sheet.
            .presentationCornerRadius(26)
            .presentationBackground(Color(hex: recipe.backgroundColorHex))
            // CRITICAL — without this, a tiny downward swipe anywhere in
            // the sheet's content was dismissing it. With `.scrolls` the
            // scroll gesture takes priority: the inner ScrollView scrolls
            // first, and ONLY when it's already at the top + the user keeps
            // dragging down does the sheet's swipe-to-dismiss engage.
            .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $editorTarget) { target in
            RecipeEditorView(recipe: target.recipe)
        }
        // Share sheet now lives inside RecipeDetailSheet — presenting it
        // from here meant SwiftUI queued it behind the detail sheet
        // (only one sheet at a time per host), which is why share
        // appeared to do nothing.
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

    // MARK: - Pull-down search hint

    /// Magnifying-glass glyph that fades + scales in as the user pulls the
    /// card list past the top. Bound to `viewModel.pullProgress` (0…1).
    /// Haptics + the actual sheet trigger live in the view-model.
    private var pullSearchHint: some View {
        let progress = viewModel.pullProgress
        return VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6 + progress * 0.4))
                .scaleEffect(0.7 + progress * 0.5)
            if progress >= 1 {
                Text("Release to search")
                    .font(.tinctaUILabel(11))
                    .foregroundStyle(.white.opacity(0.7))
                    .transition(.opacity)
            }
        }
        .opacity(progress)
        .animation(.easeOut(duration: 0.18), value: progress >= 1)
    }

    // MARK: - Card stack

    private var displayedRecipes: [Recipe] {
        viewModel.filtered(recipes)
    }

    /// Per-card sticky-pin + fading-shadow wrapper. Extracted out of
    /// `cardStack`'s ForEach so the compiler can type-check the body —
    /// the chained .visualEffect + .offset + two .shadow modifiers were
    /// pushing the parent body over the type-checker's complexity budget.
    @ViewBuilder
    private func stickyCard(recipe: Recipe, index: Int) -> some View {
        let stickyY: CGFloat = 64
        // Drop-shadow as a SEPARATE background layer behind the card so we
        // can fade it via .visualEffect.opacity (which is supported —
        // .shadow itself isn't a VisualEffect, so we can't put it inside
        // the closure directly).
        let shadowLayer = RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color.clear)
            .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: -1)
            .shadow(color: .black.opacity(0.30), radius: 14, x: 0, y: 6)
            .visualEffect { content, geo in
                let minY = geo.frame(in: .scrollView(axis: .vertical)).minY
                let pinAmount = max(0, stickyY - minY)
                // Shadow opacity 1.0 while scrolling, fades to 0 over the
                // first 30pt of being pinned at the top of the viewport,
                // so the deck doesn't read as a muddy dark blob.
                let factor = max(0, 1 - pinAmount / 30)
                return content.opacity(factor)
            }

        Button {
            detailRecipe = recipe
        } label: {
            RecipeCardView(recipe: recipe, namespace: cardNamespace)
        }
        .buttonStyle(.plain)
        .background(shadowLayer)
        // Sticky-stack: pin to `stickyY` once the top crosses the viewport
        // top inset. Later cards stack ON TOP via the zIndex below.
        .visualEffect { content, geo in
            let minY = geo.frame(in: .scrollView(axis: .vertical)).minY
            let pinAmount = max(0, stickyY - minY)
            return content.offset(y: pinAmount)
        }
        .zIndex(Double(index))
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

            // Plain VStack (not Lazy): the negative inter-item spacing collides
            // with LazyVStack's culling and makes cards disappear inside the
            // viewport. With a handful of recipes, eager rendering is fine.
            VStack(spacing: -cardOverlap) {
                // Top spacer has to absorb both the safe-area / floating-chrome
                // offset (~88pt) AND the negative spacing the VStack applies
                // between this spacer and the first card (~cardOverlap). Without
                // that compensation the first card pulls UP into the spacer and
                // gets clipped above the visible scroll area.
                Color.clear.frame(height: 88 + cardOverlap)

                ForEach(Array(displayedRecipes.enumerated()), id: \.element.id) { index, recipe in
                    stickyCard(recipe: recipe, index: index)
                }

                Color.clear.frame(height: cardOverlap + 80)
            }
            // Edge-to-edge — cards touch the left/right edges of the viewport.
            // Was .padding(.horizontal, 14).
        }
        // Allow cards to render past the ScrollView's clip bounds so they
        // don't pop in/out at the viewport edges.
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
        .coordinateSpace(name: "library-scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            viewModel.handleScrollOffsetChange(-offset)
        }
    }

    // MARK: - Floating controls

    /// Two glass chips along the top: search on the left, dropdown menu on
    /// the right. New Recipe + scan options + settings all live inside the
    /// dropdown — no more floating + button.
    private var floatingControls: some View {
        HStack {
            Button {
                showSearch = true
            } label: {
                GlassChip(systemImage: "magnifyingglass")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search recipes")
            .padding(.leading, 18)

            Spacer()

            Menu {
                Button {
                    editorTarget = .new
                } label: { Label("New Recipe", systemImage: "plus") }
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
            .padding(.trailing, 18)
        }
        .padding(.top, 12)
        .frame(maxHeight: .infinity, alignment: .top)
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

/// Adapter that renders `RecipeDetailView` inside a sheet. Presents both
/// the EDIT flow AND the SHARE sheet as stacked sheets ON TOP of itself —
/// previously share was wired up to LibraryView which couldn't present it
/// (the detail sheet was already showing, so the share queued forever).
struct RecipeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    @State private var showEditor = false
    @State private var shareRecipe: Recipe?

    var body: some View {
        RecipeDetailView(
            recipe: recipe,
            onDismiss: { dismiss() },
            onEdit: { showEditor = true },
            onShare: { shareRecipe = $0 }
        )
        .sheet(isPresented: $showEditor) {
            RecipeEditorView(recipe: recipe)
        }
        .sheet(item: $shareRecipe) { r in
            RecipeShareSheet(recipe: r)
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

// MARK: - Previews

#Preview("Library") {
    LibraryView()
        .modelContainer(TinctaModelContainer.makePreview())
}
