import SwiftUI
import Observation

/// Appearance options surfaced to the user. Maps to `ColorScheme?` for the
/// `.preferredColorScheme` view modifier.
public enum Appearance: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var display: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// User-tunable app settings, persisted via `@AppStorage` (UserDefaults).
/// Hosted as an `@Observable` singleton at the app root so any view can mutate
/// and observe it. Settings are mirrored into `UserDefaults` on every change.
@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    private let defaults: UserDefaults

    // Keys (kept private so the rest of the app can't drift them).
    private enum Key {
        static let defaultUnit = "tincta.settings.defaultUnit"
        static let appearance  = "tincta.settings.appearance"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Hydrate from defaults; fall back to sensible defaults.
        if let raw = defaults.string(forKey: Key.defaultUnit),
           let u = Unit(rawValue: raw),
           u == .oz || u == .ml {
            self._defaultUnit = u
        } else {
            self._defaultUnit = .oz
        }
        if let raw = defaults.string(forKey: Key.appearance),
           let a = Appearance(rawValue: raw) {
            self._appearance = a
        } else {
            self._appearance = .system
        }
    }

    // Backing storage observed by SwiftUI; setters persist into UserDefaults.
    private var _defaultUnit: Unit
    public var defaultUnit: Unit {
        get { _defaultUnit }
        set {
            _defaultUnit = newValue
            defaults.set(newValue.rawValue, forKey: Key.defaultUnit)
        }
    }

    private var _appearance: Appearance
    public var appearance: Appearance {
        get { _appearance }
        set {
            _appearance = newValue
            defaults.set(newValue.rawValue, forKey: Key.appearance)
        }
    }
}
