import SwiftUI
import SwiftData
import CoreText
import os

private let launchLog = Logger(subsystem: "com.tincta.app", category: "launch")

@main
struct TinctaApp: App {
    /// Built synchronously in `init`. There is NO app-level splash anymore:
    /// the iOS system launch screen (LaunchBackground colour + LaunchLogo)
    /// covers the brief container-open + seed window, and then we render
    /// straight into RootView. No async coordination edge to hang on, no
    /// "stuck splash" state.
    let container: ModelContainer

    init() {
        let start = ContinuousClock.now
        let c = TinctaModelContainer.makeContainerNonisolated()
        TinctaModelContainer.seedIfEmpty(container: c)
        self.container = c
        let elapsed = ContinuousClock.now - start
        launchLog.notice("Container + seed ready in \(elapsed.components.seconds)s")

        // Font registration is the one thing we keep off-main — TTF parse +
        // validate is genuinely expensive enough to push past the launch
        // watchdog on cold start. UI will briefly render with the system
        // serif fallback until this completes, then re-resolve.
        Task.detached(priority: .userInitiated) {
            Self.registerBundledFonts()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .tinctaTypography()
                .preferredColorScheme(.dark)
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
