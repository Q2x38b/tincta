import SwiftUI
import SwiftData
import os

private let launchLog = Logger(subsystem: "com.tincta.app", category: "launch")

@main
struct TinctaApp: App {
    /// Resolved on a background task in `LaunchGate.task` — keeps `init` cheap
    /// so the launch screen comes down quickly.
    @State private var container: ModelContainer?

    init() {
        launchLog.notice("TinctaApp.init")
        // Kick off Foundation Models prewarm on a low-priority background
        // task so the heavy framework load + first-session init is amortised
        // across the time the user spends browsing the library. By the time
        // they tap "Scan", inference is hot. Detached so it never blocks
        // SwiftUI's main scene init.
        Task.detached(priority: .background) {
            await RecipeParser.prewarm()
            launchLog.notice("RecipeParser.prewarm complete")
        }
    }

    var body: some Scene {
        WindowGroup {
            LaunchGate(container: $container)
                .tinctaTypography()
                .preferredColorScheme(.dark)
        }
    }
}

/// Renders the real `RootView` once the SwiftData container is ready, and a
/// parchment splash with a glass cup glyph until then. The async load runs on
/// a background actor so the first frame paints instantly.
private struct LaunchGate: View {
    @Binding var container: ModelContainer?
    @State private var pulse = false

    var body: some View {
        Group {
            if let container {
                RootView()
                    .modelContainer(container)
            } else {
                splash
            }
        }
        .task(priority: .userInitiated) {
            // Skip the async load if the container is already initialised.
            guard container == nil else { return }
            let start = ContinuousClock.now
            launchLog.notice("makeSharedAsync: starting")
            let resolved = await TinctaModelContainer.makeSharedAsync()
            let elapsed = ContinuousClock.now - start
            launchLog.notice("makeSharedAsync: done in \(elapsed.components.seconds).\(elapsed.components.attoseconds / 100_000_000_000_000_000)s")
            await MainActor.run { container = resolved }
        }
    }

    private var splash: some View {
        ZStack {
            Color.tinctaInk.ignoresSafeArea()
            VStack(spacing: 22) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 132, height: 132)
                    .opacity(pulse ? 0.95 : 0.65)
                    .scaleEffect(pulse ? 1.0 : 0.96)
                    .animation(
                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: pulse
                    )
                Text("Pouring your bar…")
                    .font(.tinctaUILabel(12))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .onAppear { pulse = true }
        .accessibilityLabel("Loading Tincta")
    }
}
