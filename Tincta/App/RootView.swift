import SwiftUI
import SwiftData

/// Entry point for the app's UI tree.
///
/// During M0 this shows a placeholder. The integration pass replaces the body
/// with `LibraryView()` once the parallel feature branches have merged.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tinctaInk.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Tincta")
                        .font(.tinctaDisplay(64))
                        .foregroundStyle(.white)
                    Text("\(recipes.count) recipes seeded")
                        .font(.tinctaUILabel(14))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(TinctaModelContainer.makePreview())
}
