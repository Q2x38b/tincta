import Foundation
import Observation

/// View model that owns the Library screen's search and navigation state.
/// Persistence reads stay on the view via `@Query`; the view model only
/// holds UI-derived state so previews and unit tests stay light.
@Observable
final class LibraryViewModel {
    /// Current search query string. Empty string means "no filter".
    var searchText: String = ""

    /// Whether the inline search overlay is visible.
    var isSearchPresented: Bool = false

    /// Tracks scroll offset at the top of the list for pull-down search gestures.
    var topScrollOffset: CGFloat = 0
    var lastScrollOffset: CGFloat = 0

    init() {}

    /// Case-insensitive contains check across name, ingredient names, and group tags.
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

    /// Called whenever the list's vertical scroll offset changes. Uses a simple
    /// threshold rule (per the M0 hint): if the top of the list is pulled down
    /// more than 80pt with a downward delta of at least 8pt, present search.
    func handleScrollOffsetChange(_ newOffset: CGFloat) {
        let delta = newOffset - lastScrollOffset
        lastScrollOffset = newOffset
        topScrollOffset = newOffset

        if !isSearchPresented, newOffset > 80, delta > 8 {
            isSearchPresented = true
        } else if isSearchPresented, newOffset < -20 {
            // Scrolling back up dismisses the search overlay.
            dismissSearch()
        }
    }

    func dismissSearch() {
        isSearchPresented = false
        searchText = ""
    }
}
