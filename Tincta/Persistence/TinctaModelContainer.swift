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
    ])

    /// Persistent on-disk container used by the live app.
    @MainActor
    static func makeShared() -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            seedIfEmpty(container: container)
            return container
        } catch {
            fatalError("Failed to create Tincta ModelContainer: \(error)")
        }
    }

    /// Async variant: opens the persistent store off-main (the expensive bit
    /// on a cold launch) and only hops to the main actor for the seed step.
    /// Called from `TinctaApp` so launch can paint the parchment splash
    /// immediately instead of stalling on the synchronous M0 init.
    static func makeSharedAsync() async -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create Tincta ModelContainer: \(error)")
        }
        await MainActor.run {
            seedIfEmpty(container: container)
        }
        return container
    }

    /// In-memory container used by previews and tests. Always pre-seeded so the
    /// preview canvas shows realistic content.
    @MainActor
    static func makePreview() -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            SeedData.populate(context: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }

    /// Seeds the container with starter recipes only when the store is empty.
    @MainActor
    private static func seedIfEmpty(container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Recipe>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }
        SeedData.populate(context: context)
    }
}
