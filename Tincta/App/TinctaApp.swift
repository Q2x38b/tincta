import SwiftUI
import SwiftData
import os

private let launchLog = Logger(subsystem: "com.tincta.app", category: "launch")

@main
struct TinctaApp: App {
    /// Container is loaded ASYNC off the main actor so the iOS launch
    /// watchdog never sees a slow `init()`. The splash paints immediately;
    /// the real UI swaps in once the SwiftData store + seed are ready.
    @State private var container: ModelContainer?

    init() {
        // CRITICAL: do absolutely nothing heavy here. The iOS launch
        // watchdog kills the process if the first frame doesn't render
        // within ~10s, and dyld linking the rest of the SDK frameworks
        // (Vision, VisionKit, PhotosUI, FoundationModels, SwiftData)
        // already eats most of that window on cold launches. Any extra
        // synchronous work here pushes us over the cliff.
        launchLog.notice("TinctaApp.init")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView()
                        .modelContainer(container)
                        .tinctaTypography()
                } else {
                    splash
                        .onAppear { startContainerLoad() }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Splash

    @State private var splashPulse = false

    private var splash: some View {
        ZStack {
            Color.tinctaInk.ignoresSafeArea()
            VStack(spacing: 22) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 132, height: 132)
                    .opacity(splashPulse ? 0.95 : 0.65)
                    .scaleEffect(splashPulse ? 1.0 : 0.96)
                    .animation(
                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: splashPulse
                    )
                Text("Pouring your bar…")
                    .font(.tinctaUILabel(13))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .onAppear { splashPulse = true }
        .accessibilityLabel("Loading Tincta")
    }

    // MARK: - Loader

    /// Starts the container load on a detached task. .onAppear lets us kick
    /// it off without the `.task` modifier's cancellation semantics — a
    /// detached Task survives view-identity changes (which is what made the
    /// earlier `.task`-based LaunchGate hang on re-foregrounding).
    private func startContainerLoad() {
        guard container == nil else { return }
        Task.detached(priority: .userInitiated) {
            let start = ContinuousClock.now
            let store = TinctaModelContainer.makeContainerNonisolated()
            let storeTime = ContinuousClock.now - start
            launchLog.notice("ModelContainer opened in \(storeTime.components.seconds)s")

            await MainActor.run {
                TinctaModelContainer.seedIfEmpty(container: store)
                self.container = store
            }
        }
        // NB: Foundation Models prewarm DELIBERATELY removed. It was the
        // "stuck UI after re-foreground" trigger — even on a detached task
        // the API hops back to MainActor internally. First Scan tap will
        // just pay the prewarm cost on demand instead.
    }
}
