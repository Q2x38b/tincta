import SwiftUI
import SwiftData

@main
struct TinctaApp: App {
    /// Resolved on a background task in `LaunchGate.task` — keeps `init` cheap
    /// so the launch screen comes down quickly. Until it's ready, the gate
    /// shows the parchment splash so the user never sees a black void.
    @State private var container: ModelContainer?

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
            // Skip the async load if the container is already initialised
            // (happens on background-to-foreground re-entry, not on cold launch).
            guard container == nil else { return }
            let resolved = await TinctaModelContainer.makeSharedAsync()
            await MainActor.run { container = resolved }
        }
    }

    private var splash: some View {
        ZStack {
            Color.tinctaInk.ignoresSafeArea()
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .opacity(0.85)
        }
        .accessibilityLabel("Loading Tincta")
    }
}
