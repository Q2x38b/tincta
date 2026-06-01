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
    /// Current search query string. Live-bound to the inline search bar's
    /// TextField — the card list re-filters as the user types.
    var searchText: String = ""

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

    /// What part of the recipe a query matched against. Drives the
    /// "Contains X" badge rendered on cards that matched on something
    /// other than the recipe name. The associated value is whatever the
    /// card should surface — for `.direction` it's a trimmed snippet of
    /// the matching step line.
    enum MatchKind: Equatable {
        case name
        case ingredient(String)
        case tag(String)
        case direction(String)
        case credit(String)
    }

    /// Returns the strongest match kind for `recipe` against the query, or
    /// nil if no part matched. Priority: name > ingredient > tag > step
    /// (a single directions line) > credit. Cheap O(fields) per recipe —
    /// no precomputed index since the deck is at most a few hundred items
    /// and SwiftUI rate-limits TextField updates already.
    func match(_ recipe: Recipe, query rawQuery: String) -> MatchKind? {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return .name }
        if recipe.name.lowercased().contains(query) {
            return .name
        }
        if let ing = recipe.orderedIngredients.first(where: {
            $0.name.lowercased().contains(query)
        }) {
            return .ingredient(ing.name)
        }
        if let tag = recipe.groupTags.first(where: { $0.lowercased().contains(query) }) {
            return .tag(tag)
        }
        // Per-line scan so the snippet has a clean boundary to show on
        // the card badge. Short-circuits on the first matching line.
        for line in recipe.directions.split(whereSeparator: { $0 == "\n" }) {
            if line.lowercased().contains(query) {
                return .direction(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        if let credit = recipe.credit, credit.lowercased().contains(query) {
            return .credit(credit)
        }
        return nil
    }

    /// Convenience boolean wrapper for places that just want yes/no.
    func matches(_ recipe: Recipe, query rawQuery: String) -> Bool {
        match(recipe, query: rawQuery) != nil
    }

    /// Applies the current search query and returns each matching recipe
    /// paired with WHAT matched. Empty query → every recipe with .name.
    func filteredWithMatches(_ recipes: [Recipe]) -> [(Recipe, MatchKind)] {
        let raw = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return recipes.map { ($0, .name) }
        }
        return recipes.compactMap { recipe in
            match(recipe, query: raw).map { (recipe, $0) }
        }
    }

    /// Back-compat: applies the query and returns just the recipes.
    func filtered(_ recipes: [Recipe]) -> [Recipe] {
        filteredWithMatches(recipes).map(\.0)
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

}
