import SwiftUI
import SwiftData

@main
struct TinctaApp: App {
    let container: ModelContainer

    init() {
        self.container = TinctaModelContainer.makeShared()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .tinctaTypography()
        }
    }
}
