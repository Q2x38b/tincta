import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// View model that owns the Library screen's pull-down-to-search state and
/// query filtering. Persistence reads stay on the view via `@Query`; the view
/// model only holds UI-derived state so previews and unit tests stay light.
@Observable
final class LibraryViewModel {
    /// Current search query string. Used by the inline filter (still wired
    /// up so previews work) — the main search now lives in `LibrarySearchView`.
    var searchText: String = ""

    /// Legacy flag kept so existing code paths compile. The current Library
    /// no longer renders the inline overlay; the pull gesture opens
    /// `LibrarySearchView` instead.
    var isSearchPresented: Bool = false

    // MARK: - Pull-down-to-search

    /// 0…1, where 1 means the user has pulled past the trigger threshold.
    /// The view binds this to the icon's opacity + scale so the user gets
    /// visual feedback as they pull.
    var pullProgress: Double = 0

    /// `true` once the user has pulled past `pullThreshold`. Stays true
    /// until they release (offset returns toward 0), at which point the
    /// view consumes `shouldOpenSearch` and opens the sheet.
    private var pullArmed: Bool = false

    /// One-shot flag the view watches with `.onChange`. Setting back to
    /// `false` clears the trigger so it can fire again on the next pull.
    var shouldOpenSearch: Bool = false

    /// Distance (pt) the user has to pull past the top of the list before
    /// the search icon is fully formed and the gesture is "armed".
    private let pullThreshold: CGFloat = 90

    /// Pre-create the haptic generator so the first fire isn't laggy.
    #if canImport(UIKit)
    private let armHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let triggerHaptic = UIImpactFeedbackGenerator(style: .medium)
    #endif

    init() {
        #if canImport(UIKit)
        armHaptic.prepare()
        triggerHaptic.prepare()
        #endif
    }

    // MARK: - Search filter

    /// Case-insensitive contains check across name, ingredients, and tags.
    func matches(_ recipe: Recipe, query rawQuery: String) -> Bool {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        if recipe.name.lowercased().contains(query) { return true }
        if recipe.groupTags.contains(where: { $0.lowercased().contains(query) }) {
            return true
        }
        if recipe.orderedIngredients.contains(where: { $0.name.lowercased().contains(query) }) {
            return true
        }
        return false
    }

    /// Applies the current search query to a list of recipes.
    func filtered(_ recipes: [Recipe]) -> [Recipe] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return recipes }
        return recipes.filter { matches($0, query: query) }
    }

    // MARK: - Scroll handler

    /// Called whenever the list's vertical scroll offset changes. Positive
    /// values mean the user has pulled DOWN past the top (overscroll).
    ///
    /// State machine:
    ///   pullProgress updates continuously (0 at offset≤0, 1 at threshold).
    ///   Crossing the threshold UP fires a soft haptic (the "armed" cue).
    ///   Releasing back toward 0 while armed fires a medium haptic + sets
    ///     `shouldOpenSearch` so the view can present the search sheet.
    func handleScrollOffsetChange(_ rawOffset: CGFloat) {
        // `rawOffset` from the preference key is positive when scrolled UP
        // (content above the viewport) and negative when pulled DOWN past
        // the top (overscroll). We want a positive pull distance.
        let pull = max(0, -rawOffset)
        let progress = min(1, Double(pull / pullThreshold))

        // Update visual progress on every change.
        pullProgress = progress

        // Threshold crossing UP — arm the trigger, fire soft haptic.
        if !pullArmed, progress >= 1 {
            pullArmed = true
            #if canImport(UIKit)
            armHaptic.impactOccurred(intensity: 0.6)
            armHaptic.prepare()
            #endif
        }

        // Released back toward zero while armed — fire the trigger.
        if pullArmed, progress < 0.15 {
            pullArmed = false
            shouldOpenSearch = true
            #if canImport(UIKit)
            triggerHaptic.impactOccurred(intensity: 0.85)
            triggerHaptic.prepare()
            #endif
        }
    }

    /// Called by the view after consuming `shouldOpenSearch`.
    func clearOpenSearchTrigger() {
        shouldOpenSearch = false
    }

    /// Legacy — kept so the inline-overlay code path doesn't break.
    func dismissSearch() {
        isSearchPresented = false
        searchText = ""
    }
}
