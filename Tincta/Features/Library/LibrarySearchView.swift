import SwiftUI
import SwiftData

/// Full-screen search sheet presented from the floating top-left button.
///
/// Indexes recipes by both their name and their ingredient names. Hits are
/// case-insensitive substring matches, sorted with name-matches first.
struct LibrarySearchView: View {
    @Environment(\.dismiss) private var dismiss
    let recipes: [Recipe]
    let onPick: (Recipe) -> Void

    @State private var query: String = ""
    @State private var index: [SearchEntry] = []
    @FocusState private var fieldFocused: Bool

    /// Pre-built lowercased lookup for one recipe. Built once when the sheet
    /// appears (and refreshed if the input list changes), so each keystroke
    /// only does cheap String.contains + edit-distance work against already-
    /// lowercased strings — no per-keystroke .lowercased() / .sorted().
    private struct SearchEntry {
        let recipe: Recipe
        let lowerName: String
        /// Tokenised whole-words from name + ingredient names. Used by the
        /// fuzzy matcher so typos like "shalken" can find "shaken".
        let tokens: [String]
        let lowerIngredients: [String]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                List {
                    ForEach(matches) { match in
                        Button {
                            onPick(match.recipe)
                        } label: {
                            SearchRow(match: match, query: query)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Color.tinctaInk.ignoresSafeArea())
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                fieldFocused = true
                rebuildIndex()
            }
            .onChange(of: recipes) { _, _ in rebuildIndex() }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))
            TextField(
                "",
                text: $query,
                prompt: Text("Search recipes")
                    .foregroundStyle(.white.opacity(0.4))
            )
            .textFieldStyle(.plain)
            .foregroundStyle(.white)
            .submitLabel(.search)
            .focused($fieldFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Matching

    struct SearchMatch: Identifiable {
        let recipe: Recipe
        let kind: Kind
        var id: UUID { recipe.id }
        enum Kind {
            case name
            case ingredient(String)
            case all  // empty query → show everything
        }
    }

    private var matches: [SearchMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return index.map { SearchMatch(recipe: $0.recipe, kind: .all) }
        }
        // Three tiers, ranked best → worst:
        //   1. Substring hit in the recipe name           (exact-ish)
        //   2. Substring hit in an ingredient name        (exact-ish)
        //   3. Fuzzy hit (edit distance ≤ tolerance) on any token
        //      from the name or ingredients                (typo tolerance —
        //      this is what makes "shalken" find "shaken")
        var nameHits: [SearchMatch] = []
        var ingHits: [SearchMatch] = []
        var fuzzyHits: [SearchMatch] = []

        // Edit-distance tolerance scales with query length. Tiny queries can
        // match too much if we allow many edits, so cap them tight.
        let tolerance: Int = {
            switch trimmed.count {
            case 0...3:  return 0       // too short — only exact matches
            case 4...5:  return 1
            case 6...9:  return 2
            default:     return 3
            }
        }()

        for entry in index {
            if entry.lowerName.contains(trimmed) {
                nameHits.append(.init(recipe: entry.recipe, kind: .name))
                continue
            }
            if let idx = entry.lowerIngredients.firstIndex(where: { $0.contains(trimmed) }) {
                let originalName = entry.recipe.orderedIngredients[idx].name
                ingHits.append(.init(recipe: entry.recipe, kind: .ingredient(originalName)))
                continue
            }
            // Fuzzy fallback. Walk every token in the entry and look for one
            // close to the query. First close-enough hit wins.
            if tolerance > 0,
               let fuzzy = entry.tokens.first(where: {
                   editDistance($0, trimmed) <= tolerance
               }) {
                fuzzyHits.append(.init(recipe: entry.recipe, kind: .ingredient(fuzzy)))
            }
        }
        return nameHits + ingHits + fuzzyHits
    }

    /// Pre-lowercases every recipe name + every ingredient name once. Called
    /// on appear and whenever the input list changes. Keystroke search then
    /// becomes a pure string-contains + edit-distance loop.
    private func rebuildIndex() {
        index = recipes.map { recipe in
            let lowerName = recipe.name.lowercased()
            let lowerIngs = recipe.orderedIngredients.map { $0.name.lowercased() }
            // One token per whole word across name + ingredients. We dedupe
            // and drop tokens shorter than 3 chars since they generate too
            // many fuzzy false-positives.
            var tokens = Set<String>()
            for src in [lowerName] + lowerIngs {
                for word in src.split(whereSeparator: { !$0.isLetter }) where word.count >= 3 {
                    tokens.insert(String(word))
                }
            }
            return SearchEntry(
                recipe: recipe,
                lowerName: lowerName,
                tokens: Array(tokens),
                lowerIngredients: lowerIngs
            )
        }
    }
}

// MARK: - Edit distance

/// Plain Levenshtein distance — minimum single-char insertions, deletions,
/// or substitutions to turn `a` into `b`. O(n*m) time, O(min(n,m)) space.
/// Used by the search view's fuzzy fallback for typo tolerance.
private func editDistance(_ a: String, _ b: String) -> Int {
    let lhs = Array(a)
    let rhs = Array(b)
    if lhs.isEmpty { return rhs.count }
    if rhs.isEmpty { return lhs.count }

    var previous = Array(0...rhs.count)
    var current = Array(repeating: 0, count: rhs.count + 1)

    for i in 1...lhs.count {
        current[0] = i
        for j in 1...rhs.count {
            let cost = lhs[i - 1] == rhs[j - 1] ? 0 : 1
            current[j] = min(
                current[j - 1] + 1,          // insertion
                previous[j] + 1,             // deletion
                previous[j - 1] + cost       // substitution
            )
        }
        swap(&previous, &current)
    }
    return previous[rhs.count]
}

// MARK: - Row

private struct SearchRow: View {
    let match: LibrarySearchView.SearchMatch
    let query: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: match.recipe.backgroundColorHex))
                .frame(width: 38, height: 50)
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(match.recipe.name)
                    .font(.tinctaUILabel(14))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.tinctaBody(12))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(.white.opacity(0.08))
    }

    private var subtitle: String {
        switch match.kind {
        case .name, .all:
            return match.recipe.orderedIngredients
                .prefix(3)
                .map(\.name)
                .joined(separator: " · ")
        case .ingredient(let name):
            return "Contains \(name)"
        }
    }
}

#Preview {
    LibrarySearchView(recipes: []) { _ in }
        .modelContainer(TinctaModelContainer.makePreview())
}
