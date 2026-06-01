import SwiftUI
import SwiftData
import os

private let launchLog = Logger(subsystem: "com.tincta.app", category: "launch")

@main
struct TinctaApp: App {
    /// Container is built synchronously in App init. The iOS launch screen
    /// (parchment-on-ink + logo) is what the user sees during that work —
    /// once init returns, the first SwiftUI frame paints `RootView` directly.
    ///
    /// We previously used a LaunchGate splash + async container init so the
    /// first SwiftUI frame could paint while the store opened in the
    /// background. That added a coordination edge that could hang (the
    /// `.task` would never resolve in some launch paths, and the user had
    /// to kill the app and reopen). Sync init has no such edge — the worst
    /// case is the iOS launch screen lingering a couple extra seconds.
    let container: ModelContainer

    init() {
        let start = ContinuousClock.now
        self.container = TinctaModelContainer.makeShared()
        let elapsed = ContinuousClock.now - start
        launchLog.notice("ModelContainer ready in \(elapsed.components.seconds)s")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .tinctaTypography()
                .preferredColorScheme(.dark)
                // Foundation Models prewarm moved here from init() so it
                // never races with the SwiftUI first-frame path. Runs once,
                // detached, at background priority — by the time the user
                // taps "Scan", the LLM is hot.
                .task(priority: .background) {
                    await RecipeParser.prewarm()
                    launchLog.notice("RecipeParser.prewarm complete")
                }
        }
    }
}
