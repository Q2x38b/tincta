import SwiftUI
import SwiftData
import os

private let launchLog = Logger(subsystem: "com.tincta.app", category: "launch")

@main
struct TinctaApp: App {
    @State private var container: ModelContainer?

    init() {
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

    /// Plain static splash — NO pulse animation. The previous infinite
    /// .repeatForever drove a SwiftUI runloop heartbeat that competed with
    /// the (already slow) container init for main-thread cycles. A static
    /// image is also what iOS's own launch screen renders, so transitioning
    /// from launch image → this view is visually seamless.
    private var splash: some View {
        ZStack {
            Color.tinctaInk.ignoresSafeArea()
            VStack(spacing: 22) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 132, height: 132)
                    .opacity(0.85)
                Text("Loading…")
                    .font(.tinctaUILabel(13))
                    .foregroundStyle(.white.opacity(0.45))
            }

            // Pre-warm the Liquid Glass Metal shader off-screen. The first
            // time a glassEffect renders on iOS, the shader compiles and
            // that compile blocks the main thread for ~300-800ms. Mounting
            // a tiny invisible GlassChip during the splash means the shader
            // is already compiled by the time the user sees the Library's
            // floating chips — no visible freeze on first paint.
            GlassChip(systemImage: "circle")
                .frame(width: 1, height: 1)
                .opacity(0.001)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Loading Tincta")
    }

    // MARK: - Loader

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
    }
}
