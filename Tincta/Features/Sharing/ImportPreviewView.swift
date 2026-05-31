import SwiftUI
import SwiftData

/// Sheet shown after the user taps a Tincta share link. Lists every recipe
/// in the payload so the user can confirm before anything is written to disk.
struct ImportPreviewView: View {
    let transfer: RecipeTransfer

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    @State private var importError: String?

    /// Called after a successful import so the host can pop into the library,
    /// scroll to the new entries, etc. Optional — defaults to a no-op.
    var onImported: (([Recipe]) -> Void)?

    init(transfer: RecipeTransfer, onImported: (([Recipe]) -> Void)? = nil) {
        self.transfer = transfer
        self.onImported = onImported
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headline
                    recipeList
                    if let importError {
                        Text(importError)
                            .font(.tinctaBody(14))
                            .foregroundStyle(Color.red)
                            .padding(.top, 4)
                    }
                }
                .padding(24)
            }
            .background(Color.tinctaParchment.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .navigationTitle("Import Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headlineText)
                .font(.tinctaDisplay(28))
                .foregroundStyle(Color.tinctaInk)
                .fixedSize(horizontal: false, vertical: true)
            Text("These will be added to your library as new recipes. Originals remain untouched.")
                .font(.tinctaBody(14))
                .foregroundStyle(Color.tinctaInk.opacity(0.7))
        }
    }

    private var recipeList: some View {
        VStack(spacing: 12) {
            ForEach(transfer.recipes) { payload in
                row(for: payload)
            }
        }
    }

    private func row(for payload: RecipePayload) -> some View {
        let background = Color(hex: payload.backgroundColorHex)
        let foreground = contrastingForeground(forHex: payload.backgroundColorHex)
        return HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(background)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(String(payload.name.prefix(1)).uppercased())
                        .font(.tinctaDisplay(24))
                        .foregroundStyle(foreground)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(payload.name)
                    .font(.tinctaDisplay(18))
                    .foregroundStyle(Color.tinctaInk)
                    .lineLimit(1)
                Text(ingredientSummary(for: payload))
                    .font(.tinctaBody(13))
                    .foregroundStyle(Color.tinctaInk.opacity(0.65))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .tinctaShadow.opacity(0.4), radius: 6, x: 0, y: 2)
        )
    }

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.2)
            Button(action: confirmImport) {
                HStack(spacing: 10) {
                    if isImporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "tray.and.arrow.down.fill")
                    }
                    Text(confirmTitle)
                        .font(.tinctaUILabel(15))
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.tinctaInk)
            .foregroundStyle(.white)
            .disabled(isImporting || transfer.recipes.isEmpty)
            .padding(16)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func confirmImport() {
        guard !isImporting else { return }
        isImporting = true
        importError = nil
        do {
            let inserted = try TransferCodec.importPayload(transfer, into: modelContext)
            onImported?(inserted)
            isImporting = false
            dismiss()
        } catch {
            isImporting = false
            importError = "Couldn't save the imported recipes: \(error.localizedDescription)"
        }
    }

    // MARK: - Strings

    private var headlineText: String {
        switch transfer.recipes.count {
        case 0:
            return "Nothing to import"
        case 1:
            return "Import \u{201C}\(transfer.recipes[0].name)\u{201D}?"
        case 2:
            return "Import \u{201C}\(transfer.recipes[0].name)\u{201D} + 1 other?"
        default:
            return "Import \u{201C}\(transfer.recipes[0].name)\u{201D} + \(transfer.recipes.count - 1) others?"
        }
    }

    private var confirmTitle: String {
        let count = transfer.recipes.count
        return count <= 1 ? "ADD TO LIBRARY" : "ADD \(count) RECIPES"
    }

    private func ingredientSummary(for payload: RecipePayload) -> String {
        let names = payload.ingredients
            .sorted { $0.order < $1.order }
            .map { $0.name.uppercased() }
        if names.isEmpty { return "No ingredients" }
        return names.joined(separator: " · ")
    }
}

// MARK: - Preview

private struct ImportPreviewPreviewHost: View {
    @Query private var recipes: [Recipe]
    var body: some View {
        let transfer = RecipeTransfer(
            recipes: Array(recipes.prefix(3)).map(RecipePayload.init(recipe:))
        )
        ImportPreviewView(transfer: transfer)
    }
}

#Preview("Import Preview") {
    let container = TinctaModelContainer.makePreview()
    return ImportPreviewPreviewHost()
        .modelContainer(container)
}
