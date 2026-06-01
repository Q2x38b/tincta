import SwiftUI
import SwiftData

/// User preferences. Hosted in a NavigationStack by the presenter
/// (typically as a `.sheet` from the top-right menu).
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]
    @Bindable var settings: AppSettings

    @State private var confirmDeleteAll = false
    @State private var deletionError: String?

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
                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        HStack {
                            Label("Delete All Recipes", systemImage: "trash")
                            Spacer()
                            Text("\(recipes.count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .disabled(recipes.isEmpty)
                } header: {
                    Text("Library")
                } footer: {
                    Text("Permanently removes every recipe in your library. This cannot be undone.")
                }

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
            .confirmationDialog(
                "Delete all \(recipes.count) recipes?",
                isPresented: $confirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    deleteAllRecipes()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove every recipe in your library.")
            }
            .alert(
                "Couldn't Delete",
                isPresented: Binding(
                    get: { deletionError != nil },
                    set: { if !$0 { deletionError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let msg = deletionError { Text(msg) }
            }
        }
    }

    /// Removes every Recipe from the model context and saves. SwiftData
    /// cascade-deletes the owned Ingredient and DrinkLook rows via the
    /// `.cascade` relationship on Recipe.
    private func deleteAllRecipes() {
        for recipe in recipes {
            modelContext.delete(recipe)
        }
        do {
            try modelContext.save()
        } catch {
            deletionError = error.localizedDescription
        }
    }
}

#Preview("Settings") {
    SettingsView(settings: AppSettings())
}
