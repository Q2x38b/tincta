import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// User preferences. Hosted in a NavigationStack by the presenter
/// (typically as a `.sheet` from the top-right menu).
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]
    @Bindable var settings: AppSettings

    @State private var confirmDeleteAll = false
    @State private var deletionError: String?

    @State private var exportedToken: String?
    @State private var exportError: String?
    @State private var exportCopied = false

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
                    Button {
                        exportAllRecipes()
                    } label: {
                        HStack {
                            Label("Export All to Code", systemImage: "square.and.arrow.up")
                            Spacer()
                            Text("\(recipes.count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .disabled(recipes.isEmpty)

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
                    Text("Export bundles every recipe into a single share code. Delete permanently removes them — this cannot be undone.")
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
            .alert(
                "Couldn't Export",
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let msg = exportError { Text(msg) }
            }
            .sheet(isPresented: Binding(
                get: { exportedToken != nil },
                set: { if !$0 { exportedToken = nil; exportCopied = false } }
            )) {
                if let token = exportedToken {
                    ExportTokenSheet(token: token, recipeCount: recipes.count, copied: $exportCopied)
                }
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

    /// Bundles every recipe in the library into a single transfer token and
    /// presents it as a share/copy sheet. Same encoder the per-recipe share
    /// uses; recipients paste the token via Library → ⋯ → Paste Code.
    private func exportAllRecipes() {
        do {
            let token = try TransferCodec.encode(recipes: recipes)
            exportedToken = token
            #if canImport(UIKit)
            UIPasteboard.general.string = token
            exportCopied = true
            #endif
        } catch {
            exportError = error.localizedDescription
        }
    }
}

// MARK: - Export sheet

/// Modal that displays the bundled share token, lets the user re-copy it,
/// and offers the system share sheet. Kept inside SettingsView's file since
/// it's specific to the export flow.
private struct ExportTokenSheet: View {
    let token: String
    let recipeCount: Int
    @Binding var copied: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(recipeCount) \(recipeCount == 1 ? "recipe" : "recipes") encoded")
                            .font(.tinctaUILabel(15))
                            .foregroundStyle(.secondary)
                        Text("Paste this into another Tincta library via ⋯ → Paste Code, or send the token below.")
                            .font(.tinctaBody(14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Text(token)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        #if canImport(UIKit)
                        Button {
                            UIPasteboard.general.string = token
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                copied = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: copied ? "checkmark" : "clipboard")
                                Text(copied ? "Copied to Clipboard" : "Copy Code")
                                    .font(.tinctaUILabel(15))
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        #endif

                        ShareLink(
                            item: token,
                            subject: Text("Tincta recipes"),
                            message: Text("Paste this code into Tincta → ⋯ → Paste Code")
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Code")
                                    .font(.tinctaUILabel(15))
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Export Library")
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
