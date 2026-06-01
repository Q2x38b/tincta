import Foundation
import SwiftData

/// Centralized factory for the app's SwiftData container. Keeps the schema
/// declared in one place and offers a preview/in-memory variant for SwiftUI
/// previews and unit tests.
enum TinctaModelContainer {

    static let schema = Schema([
        Recipe.self,
        Ingredient.self,
        DrinkLook.self,
        RecipeSize.self,
        SizeAmount.self,
    ])

    /// The on-disk configuration we use for both sync + async openers. The
    /// `cloudKitDatabase: .none` is explicit so SwiftData doesn't try to
    /// negotiate with CloudKit on launch (which is one of the biggest
    /// hidden time-sinks during cold start on real devices, and we don't
    /// use sync anyway).
    private static var liveConfig: ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )
    }

    /// Opens the persistent store WITHOUT any actor isolation, so it can
    /// be called from a `Task.detached` in `TinctaApp` and never touch the
    /// main actor. This is what keeps the splash painting smoothly during
    /// cold launches — the slow part of SwiftData is store creation, and
    /// it doesn't need to be on main.
    nonisolated static func makeContainerNonisolated() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [liveConfig])
        } catch {
            fatalError("Failed to create Tincta ModelContainer: \(error)")
        }
    }

    /// Seeds the container with starter recipes only when the store is empty.
    /// MainActor-isolated because it uses `container.mainContext`.
    @MainActor
    static func seedIfEmpty(container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Recipe>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }
        SeedData.populate(context: context)
    }

    /// Sync convenience for code paths that don't go through TinctaApp
    /// (currently nothing, kept as a fallback). Opens the store and seeds
    /// on the main actor — slow at cold start, so prefer the async path.
    @MainActor
    static func makeShared() -> ModelContainer {
        let container = makeContainerNonisolated()
        seedIfEmpty(container: container)
        return container
    }

    /// In-memory container used by previews and tests. Always pre-seeded so
    /// the preview canvas shows realistic content.
    @MainActor
    static func makePreview() -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            SeedData.populate(context: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }
}
