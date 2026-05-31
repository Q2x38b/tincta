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
    /// only does cheap `String.contains` calls against already-lowercased
    /// strings — no per-keystroke .lowercased() / .sorted() work.
    private struct SearchEntry {
        let recipe: Recipe
        let lowerName: String
        let lowerIngredients: [String]   // one per ingredient, already lowercased
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
        // Walk the prebuilt index — no .lowercased() or .sorted() per keystroke.
        var nameHits: [SearchMatch] = []
        var ingHits: [SearchMatch] = []
        for entry in index {
            if entry.lowerName.contains(trimmed) {
                nameHits.append(.init(recipe: entry.recipe, kind: .name))
                continue
            }
            if let idx = entry.lowerIngredients.firstIndex(where: { $0.contains(trimmed) }) {
                // Resolve the original-cased ingredient name from the recipe
                // for display. orderedIngredients here is the cached one.
                let originalName = entry.recipe.orderedIngredients[idx].name
                ingHits.append(.init(recipe: entry.recipe, kind: .ingredient(originalName)))
            }
        }
        return nameHits + ingHits
    }

    /// Pre-lowercases every recipe name + every ingredient name once. Called
    /// on appear and whenever the input list changes. Keystroke search then
    /// becomes a pure string-contains loop.
    private func rebuildIndex() {
        index = recipes.map { recipe in
            SearchEntry(
                recipe: recipe,
                lowerName: recipe.name.lowercased(),
                lowerIngredients: recipe.orderedIngredients.map { $0.name.lowercased() }
            )
        }
    }
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
                Text(match.recipe.name.uppercased())
                    .font(.tinctaUILabel(13))
                    .tracking(0.8)
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
