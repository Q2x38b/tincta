import SwiftUI
import SwiftData
import CoreText
import os

private let launchLog = Logger(subsystem: "com.tincta.app", category: "launch")

@main
struct TinctaApp: App {
    @State private var container: ModelContainer?

    init() {
        launchLog.notice("TinctaApp.init")
        // Register bundled fonts on a background task. We previously listed
        // them in Info.plist's UIAppFonts which forces iOS to parse + validate
        // the TTFs ON the main launch thread before showing the first frame —
        // measurable cause of the "stuck splash" report. CTFontManager does
        // the same thing but we can fire it off-main.
        Task.detached(priority: .userInitiated) {
            Self.registerBundledFonts()
        }
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

    // MARK: - Splash (intentionally minimal)

    /// Just a colour + tiny spinner. NO Image (forces asset lookup), NO Text
    /// (forces font resolution), NO glassEffect (forces Metal shader compile
    /// before first frame). The whole point is for `body` to return as fast
    /// as possible so `.onAppear` actually fires and kicks off the container
    /// load — anything heavy in `body` delays both the splash being visible
    /// AND the load starting.
    private var splash: some View {
        ZStack {
            Color.tinctaInk.ignoresSafeArea()
            ProgressView()
                .tint(.white.opacity(0.6))
                .controlSize(.small)
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

    // MARK: - Font registration

    private static func registerBundledFonts() {
        let filenames = [
            "CrimsonPro-Regular",
            "CrimsonPro-Italic",
            "CrimsonPro-Medium",
            "CrimsonPro-MediumItalic",
        ]
        for filename in filenames {
            guard let url = Bundle.main.url(forResource: filename, withExtension: "ttf") else {
                launchLog.error("Font missing from bundle: \(filename, privacy: .public)")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let e = error?.takeRetainedValue()
                launchLog.error("Font register failed \(filename, privacy: .public): \(String(describing: e), privacy: .public)")
            }
        }
        launchLog.notice("Custom fonts registered")
    }
}
