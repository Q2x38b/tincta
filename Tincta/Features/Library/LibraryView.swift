import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

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
    @Query(
        sort: [
            SortDescriptor(\Recipe.sortOrder, order: .forward),
            SortDescriptor(\Recipe.createdAt, order: .reverse)
        ]
    ) private var recipes: [Recipe]

    @State private var viewModel = LibraryViewModel()
    @Namespace private var cardNamespace

    // Sheet/overlay presentation state — owned by the Library since it's home.
    @State private var detailRecipe: Recipe?
    @State private var editorTarget: EditorTarget?
    @State private var importPreview: ImportPreview?
    @State private var scanSource: RecipeImportSource?
    @State private var showSettings = false
    @State private var showAbout = false
    /// Inline search bar visible state. Toggled by the search GlassChip
    /// AND by the pull-down-to-search gesture. NOT a sheet anymore.
    @State private var showInlineSearch = false
    @FocusState private var searchFieldFocused: Bool

    // MARK: - Drag-to-reorder state
    //
    // When the user long-presses a card it "lifts" (scales, drops shadow,
    // rotates slightly), then they can drag it up or down. Other cards
    // reflow in discrete `cardOverlap` increments to show the drop slot.
    // Reorder is suppressed while a search query is active (the on-screen
    // order isn't the canonical order in that case).
    /// UUID of the recipe currently being dragged. nil = no drag active.
    @State private var draggingRecipeID: UUID? = nil
    /// Continuous vertical translation of the dragged card's finger.
    @State private var dragTranslation: CGFloat = 0
    /// Original index of the card being dragged (within `displayedRecipes`).
    @State private var draggedFromIndex: Int? = nil
    /// Index the card would land at if released now. Re-derived from
    /// `dragTranslation` on every change.
    @State private var draggedToIndex: Int? = nil
    /// Drag-translation at the moment the long-press fired. Subtracted
    /// from each subsequent translation so the card doesn't jump by the
    /// finger's pre-press travel when the gesture lifts.
    @State private var dragBaseTranslation: CGFloat = 0
    /// Reusable haptics for the lift / cross-threshold / drop moments.
    #if canImport(UIKit)
    @State private var liftHaptic = UIImpactFeedbackGenerator(style: .soft)
    @State private var slotHaptic = UISelectionFeedbackGenerator()
    @State private var dropHaptic = UIImpactFeedbackGenerator(style: .medium)
    #endif

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
        .task {
            // Defer the one-shot sortOrder migration off the first render
            // frame. Running it inline in .onAppear meant mutating every
            // Recipe in the deck during the same tick as initial layout,
            // which on first-launch-after-update made the app look frozen
            // until the user swiped out and back in. The Task hop lets the
            // first interactive frame paint, then the migration runs.
            migrateSortOrderIfNeeded()
        }
        // Pull-down-to-search trigger from the view-model now expands the
        // INLINE search bar in place rather than opening a separate sheet.
        .onChange(of: viewModel.shouldOpenSearch) { _, newValue in
            if newValue {
                viewModel.clearOpenSearchTrigger()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    showInlineSearch = true
                }
                searchFieldFocused = true
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
        // Search is now an inline filter bar inside `cardStack` — no
        // separate sheet. See `inlineSearchBar` below.
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

    /// Recipes paired with WHY they matched the active search query (.name
    /// when no query is active). The "Contains X" badge on each card reads
    /// this hint.
    private var displayedRecipes: [(Recipe, LibraryViewModel.MatchKind)] {
        viewModel.filteredWithMatches(recipes)
    }

    /// Per-card sticky-pin + fading-shadow wrapper. Extracted out of
    /// `cardStack`'s ForEach so the compiler can type-check the body —
    /// the chained .visualEffect + .offset + two .shadow modifiers were
    /// pushing the parent body over the type-checker's complexity budget.
    @ViewBuilder
    private func stickyCard(recipe: Recipe, index: Int, matchHint: LibraryViewModel.MatchKind) -> some View {
        let stickyY: CGFloat = 64
        let isDragging = draggingRecipeID == recipe.id
        let reflow = reflowOffset(forIndex: index)
        // Lifted cards skip sticky-pin so they follow the finger cleanly.
        let lifted = isDragging
        // Drop-shadow as a SEPARATE background layer behind the card so we
        // can fade it via .visualEffect.opacity (which is supported —
        // .shadow itself isn't a VisualEffect, so we can't put it inside
        // the closure directly).
        let shadowLayer = RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color.clear)
            .shadow(color: .black.opacity(lifted ? 0.55 : 0.45),
                    radius: lifted ? 12 : 3,
                    x: 0, y: lifted ? 8 : -1)
            .shadow(color: .black.opacity(lifted ? 0.45 : 0.30),
                    radius: lifted ? 28 : 14,
                    x: 0, y: lifted ? 18 : 6)
            .visualEffect { [lifted] content, geo in
                if lifted {
                    return content.opacity(1)
                }
                let minY = geo.frame(in: .scrollView(axis: .vertical)).minY
                let pinAmount = max(0, stickyY - minY)
                // Shadow opacity 1.0 while scrolling, fades to 0 over the
                // first 30pt of being pinned at the top of the viewport,
                // so the deck doesn't read as a muddy dark blob.
                let factor = max(0, 1 - pinAmount / 30)
                return content.opacity(factor)
            }

        Button {
            // Suppress tap while a drag is active so the long-press lift
            // doesn't immediately also open the detail sheet on release.
            guard draggingRecipeID == nil else { return }
            detailRecipe = recipe
        } label: {
            RecipeCardView(
                recipe: recipe,
                namespace: cardNamespace,
                matchHint: matchHint
            )
        }
        .buttonStyle(.plain)
        .background(shadowLayer)
        .scaleEffect(lifted ? 1.04 : 1.0, anchor: .center)
        .rotationEffect(.degrees(lifted ? -2 : 0), anchor: .center)
        // Sticky-stack: pin to `stickyY` once the top crosses the viewport
        // top inset. Later cards stack ON TOP via the zIndex below. While
        // a card is lifted we use a plain .offset(y:) following the finger
        // INSTEAD of the sticky-pin, so the dragged card moves smoothly.
        .visualEffect { [lifted] content, geo in
            if lifted {
                return content.offset(y: 0)
            }
            let minY = geo.frame(in: .scrollView(axis: .vertical)).minY
            let pinAmount = max(0, stickyY - minY)
            return content.offset(y: pinAmount)
        }
        .offset(y: lifted ? dragTranslation : reflow)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: reflow)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: lifted)
        // Lifted cards float above everything else.
        .zIndex(lifted ? 9_999 : Double(index))
        // .simultaneousGesture (NOT .gesture) so the ScrollView's pan
        // still receives touches before a long-press fires — otherwise
        // attaching a high-priority gesture to every card means the user
        // can never scroll the library. The companion scrollDisabled()
        // call on the ScrollView toggles off ONLY after a press succeeds,
        // so during the actual drag the ScrollView gets out of the way
        // and our DragGesture is the sole consumer of finger movement.
        .simultaneousGesture(reorderGesture(for: recipe, at: index))
    }

    /// How far card `index` should slide to make room for the dragged
    /// card. Returns 0 unless something is actively being dragged.
    private func reflowOffset(forIndex index: Int) -> CGFloat {
        guard
            let from = draggedFromIndex,
            let to = draggedToIndex,
            from != to,
            index != from
        else { return 0 }
        // Card was BELOW the source slot but moved at-or-above the new
        // target → it needs to shift UP by one slot height.
        if from < to, index > from, index <= to {
            return -cardOverlap
        }
        // Card was ABOVE the source slot but the drag has moved past it
        // → shift DOWN.
        if to < from, index < from, index >= to {
            return cardOverlap
        }
        return 0
    }

    /// Long-press + drag gesture wired onto each card. Suppressed during
    /// search (the visible order isn't canonical when filtered).
    ///
    /// Uses `LongPressGesture.simultaneously(with: DragGesture)` rather
    /// than `.sequenced(before:)` because the sequenced variant has a
    /// long-standing SwiftUI bug: once the long press fires, the touch
    /// isn't reliably handed off to the inner DragGesture with a single
    /// finger — users have to lift and re-touch (or use a second
    /// finger) for the drag to register. Simultaneous gestures share
    /// the same touch end-to-end, so a single finger long-press then
    /// drag works.
    ///
    /// To stop the gesture from intercepting scroll swipes, the
    /// LongPressGesture's `maximumDistance` is left at the default 10pt
    /// — any swipe that's actually a scroll moves far enough in the
    /// first ~0.1s to cancel the press, so the ScrollView's gesture
    /// wins as normal.
    private func reorderGesture(for recipe: Recipe, at index: Int) -> some Gesture {
        let isFiltered = !viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty
        let press = LongPressGesture(minimumDuration: 0.35, maximumDistance: 10)
        let drag = DragGesture(minimumDistance: 0, coordinateSpace: .local)
        return press.simultaneously(with: drag)
            .onChanged { value in
                guard !isFiltered else { return }
                let pressFired = value.first ?? false
                let dragValue = value.second

                // Long press just succeeded → enter drag mode. Capture
                // the drag translation at THIS moment so subsequent
                // movement is relative to here, not to where the finger
                // first touched down (which can be ~0.35s of jitter
                // earlier).
                if pressFired && draggingRecipeID == nil {
                    dragBaseTranslation = dragValue?.translation.height ?? 0
                    beginDrag(for: recipe.id, fromIndex: index)
                }

                // Track movement only once the press has fired and
                // committed this card as the dragged one. Pre-press
                // jitter is ignored.
                if draggingRecipeID == recipe.id, let drag = dragValue {
                    dragTranslation = drag.translation.height - dragBaseTranslation
                    updateDropTarget()
                }
            }
            .onEnded { _ in
                // The simultaneous gesture's onEnded fires on every
                // touch-up, including quick taps where the press never
                // fired. Guard so we only run cleanup when WE owned the
                // drag.
                guard draggingRecipeID == recipe.id else { return }
                endDrag()
            }
    }

    private func beginDrag(for recipeID: UUID, fromIndex: Int) {
        // Reset translation OUTSIDE withAnimation. If the same frame that
        // fires the long-press also delivers an onChanged with a non-zero
        // translation, we want that translation to apply instantly to a
        // zeroed base, not animate through a spring.
        dragTranslation = 0
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            draggingRecipeID = recipeID
            draggedFromIndex = fromIndex
            draggedToIndex = fromIndex
        }
        #if canImport(UIKit)
        liftHaptic.impactOccurred(intensity: 0.6)
        liftHaptic.prepare()
        slotHaptic.prepare()
        #endif
    }

    private func updateDropTarget() {
        guard let from = draggedFromIndex else { return }
        // Each slot is `cardOverlap` tall in visible terms — that's the
        // distance the finger has to travel for the drop slot to move
        // by one card.
        let slotDelta = Int((dragTranslation / cardOverlap).rounded())
        let total = displayedRecipes.count
        let proposed = max(0, min(total - 1, from + slotDelta))
        if proposed != draggedToIndex {
            #if canImport(UIKit)
            slotHaptic.selectionChanged()
            slotHaptic.prepare()
            #endif
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                draggedToIndex = proposed
            }
        }
    }

    private func endDrag() {
        guard let from = draggedFromIndex else {
            resetDragState()
            return
        }
        let to = draggedToIndex ?? from
        // Phase 1: spring the dragged card to its target slot's VISUAL
        // position (where it would naturally sit at index `to` after the
        // reorder). The SwiftData write is deferred to the completion
        // block — running it here would re-fire @Query mid-spring, which
        // is what caused the "card stays floating in a broken spot" bug.
        let visualTarget = CGFloat(to - from) * cardOverlap

        #if canImport(UIKit)
        if from != to {
            dropHaptic.impactOccurred(intensity: 0.85)
            dropHaptic.prepare()
        }
        #endif

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            dragTranslation = visualTarget
        } completion: {
            // Phase 2: commit the reorder, then clear all drag state.
            // The array reorder shifts the card's natural position by
            // exactly `visualTarget`, so the moment we also reset
            // dragTranslation → 0 the card stays put visually — no jump.
            if from != to {
                commitReorder(from: from, to: to)
            }
            resetDragState()
        }
    }

    /// Clears every drag-related @State back to its idle value. Wrapped
    /// in a spring so the lift visuals (scale, rotation, shadow) animate
    /// smoothly back to flat.
    private func resetDragState() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            draggingRecipeID = nil
            draggedFromIndex = nil
            draggedToIndex = nil
            dragTranslation = 0
            dragBaseTranslation = 0
        }
    }

    /// Rewrites every Recipe.sortOrder in monotonic 0..N order to reflect
    /// the new array position. Cheap — at most a few dozen rows.
    private func commitReorder(from: Int, to: Int) {
        var pairs = displayedRecipes.map(\.0)
        guard from < pairs.count, to < pairs.count else { return }
        let moved = pairs.remove(at: from)
        pairs.insert(moved, at: to)
        for (idx, recipe) in pairs.enumerated() where recipe.sortOrder != idx {
            recipe.sortOrder = idx
        }
        do { try modelContext.save() } catch {
            // Silent — the next library appearance will retry.
        }
    }

    /// One-shot migration: if every recipe still has sortOrder == 0, the
    /// `sortOrder` field was just introduced (or this is a fresh import).
    /// Walk existing recipes in createdAt-desc order and assign sequential
    /// sortOrder values so the deck preserves its current visual order.
    private func migrateSortOrderIfNeeded() {
        guard !recipes.isEmpty else { return }
        let allZero = recipes.allSatisfy { $0.sortOrder == 0 }
        guard allZero else { return }
        let chronological = recipes.sorted { $0.createdAt > $1.createdAt }
        for (idx, recipe) in chronological.enumerated() {
            recipe.sortOrder = idx
        }
        try? modelContext.save()
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

                ForEach(Array(displayedRecipes.enumerated()), id: \.element.0.id) { index, pair in
                    stickyCard(recipe: pair.0, index: index, matchHint: pair.1)
                }

                if displayedRecipes.isEmpty && !viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    emptySearchState
                        .padding(.top, cardOverlap + 24)
                        .padding(.horizontal, 32)
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
        // Suspend scroll while a drag is active. Before a long-press
        // fires, scroll works normally because the gesture on each card
        // is `.simultaneousGesture` (it observes touches without
        // blocking the ScrollView). The moment the press succeeds and
        // `draggingRecipeID` becomes non-nil, scroll yields so the
        // DragGesture is the only thing tracking finger movement — that
        // keeps the lifted card glued to the finger instead of
        // "ghost-scrolling" together with the list.
        .scrollDisabled(draggingRecipeID != nil)
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
            if showInlineSearch {
                inlineSearchBar
                    .padding(.horizontal, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Button {
                    openInlineSearch()
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
                        Button {
                            pasteImportCode()
                        } label: { Label("Paste Code", systemImage: "doc.on.clipboard") }
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
        }
        .padding(.top, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: showInlineSearch)
        .alert(
            pasteAlertTitle ?? "",
            isPresented: Binding(
                get: { pasteAlertTitle != nil },
                set: { if !$0 { pasteAlertTitle = nil; pasteAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = pasteAlertMessage { Text(msg) }
        }
    }

    // MARK: - Inline search

    /// Search bar that takes the place of the floating chips when active.
    /// Liquid-glass capsule with a focused TextField + Cancel. As the user
    /// types, `viewModel.filteredWithMatches` re-runs and the card list
    /// (and each card's "Contains X" badge) updates in place.
    private var inlineSearchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Search recipes", text: $viewModel.searchText)
                    .font(.tinctaUILabel(15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.search)
                    .focused($searchFieldFocused)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.clear.interactive(), in: Capsule(style: .continuous))

            Button("Cancel") {
                closeInlineSearch()
            }
            .font(.tinctaUILabel(15))
            .foregroundStyle(Color.white)
        }
    }

    /// Shown inside the scroll content when a query returns zero recipes,
    /// so the user gets feedback instead of staring at an empty deck.
    private var emptySearchState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
            Text("No matches")
                .font(.tinctaDisplay(20))
                .foregroundStyle(.white.opacity(0.85))
            Text("Nothing in your library matches \u{201C}\(viewModel.searchText)\u{201D}.")
                .font(.tinctaBody(14))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func openInlineSearch() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            showInlineSearch = true
        }
        searchFieldFocused = true
    }

    private func closeInlineSearch() {
        searchFieldFocused = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            showInlineSearch = false
            viewModel.searchText = ""
        }
    }

    // MARK: - Paste import

    @State private var pasteAlertTitle: String?
    @State private var pasteAlertMessage: String?

    /// Reads the clipboard and tries to interpret it as a Tincta transfer
    /// code OR a `tincta://import?data=` URL. Surfaces success/failure via
    /// a short alert and presents the standard import preview sheet on
    /// success. Pure local — nothing leaves the device.
    private func pasteImportCode() {
        #if canImport(UIKit)
        let raw = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else {
            pasteAlertTitle = "Clipboard Empty"
            pasteAlertMessage = "Copy a Tincta share code first, then try Paste Code again."
            return
        }

        // Try the URL form first; fall back to treating the whole string as
        // a bare token. The router only knows the tincta:// scheme, so any
        // legacy https://tincta.app/r/<token> link in someone's clipboard
        // gets stripped down to its token suffix here.
        let token: String
        if let url = URL(string: raw), let extracted = UniversalLinkRouter.extractToken(from: url) {
            token = extracted
        } else if let url = URL(string: raw),
                  url.scheme?.lowercased() == "https",
                  let path = url.pathComponents.last, !path.isEmpty,
                  url.pathComponents.contains("r") {
            token = path
        } else {
            token = raw
        }

        do {
            let transfer = try TransferCodec.decode(token)
            importPreview = ImportPreview(transfer: transfer)
        } catch {
            pasteAlertTitle = "Couldn't Read Code"
            pasteAlertMessage = "That doesn't look like a Tincta share code. Make sure you've copied the full code."
        }
        #endif
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
