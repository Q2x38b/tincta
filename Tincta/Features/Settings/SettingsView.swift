import SwiftUI

/// User preferences. Hosted in a NavigationStack by the presenter
/// (typically as a `.sheet` from the top-right menu).
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Default Unit", selection: $settings.defaultUnit) {
                        Text("Ounces (oz)").tag(Unit.oz)
                        Text("Milliliters (ml)").tag(Unit.ml)
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Measurements")
                } footer: {
                    Text("Volumetric ingredients are displayed in this unit. Other ingredients are unaffected.")
                }

                // Appearance picker removed — Tincta now forces dark mode
                // app-wide via .preferredColorScheme(.dark) in TinctaApp,
                // so the System/Light/Dark options didn't actually do
                // anything.
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            Label("About Tincta", systemImage: "info.circle")
                            Spacer()
                        }
                    }
                    HStack {
                        Label("Version", systemImage: "number")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Settings") {
    SettingsView(settings: AppSettings())
}
