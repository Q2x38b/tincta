import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Bottom sheet that previews the shareable recipe card and presents a
/// `ShareLink` with both the rendered PNG and the universal import link. The
/// caller wires this up as a `.sheet(item:)` keyed on the recipe.
struct RecipeShareSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    @State private var renderedImage: ShareableImage?
    @State private var shareLink: URL?
    /// Raw base64 token, separate from the URL form. Pasted directly into
    /// the recipient's Tincta via "Paste Code" — works even when their iOS
    /// strips custom-scheme URLs from the chat (some clients refuse to
    /// link `tincta://` for users who don't have the app installed).
    @State private var shareToken: String?
    @State private var copiedToken: Bool = false
    @State private var encodingError: String?

    init(recipe: Recipe) {
        self.recipe = recipe
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    cardPreview
                    actions
                }
                .padding(24)
            }
            .background(Color.tinctaParchment.ignoresSafeArea())
            .navigationTitle("Share Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await renderAssets()
            }
        }
    }

    // MARK: - Sections

    private var cardPreview: some View {
        VStack(spacing: 12) {
            ShareableRecipeCard(recipe: recipe, width: 360)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .tinctaShadow, radius: 16, x: 0, y: 8)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            if let shareLink, let shareToken, let renderedImage {
                ShareLink(
                    item: shareLink,
                    subject: Text(recipe.name),
                    message: Text("\(recipe.name) — shared from Tincta"),
                    preview: SharePreview(
                        recipe.name,
                        image: renderedImage.image
                    )
                ) {
                    actionLabel(systemImage: "square.and.arrow.up",
                                title: "Share Link & Card")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: recipe.backgroundColorHex))
                .foregroundStyle(contrastingForeground(forHex: recipe.backgroundColorHex))

                if let png = renderedImage.pngData {
                    ShareLink(
                        item: png,
                        preview: SharePreview(
                            recipe.name,
                            image: renderedImage.image
                        )
                    ) {
                        actionLabel(systemImage: "photo",
                                    title: "Share Image Only")
                    }
                    .buttonStyle(.bordered)
                }

                ShareLink(item: shareLink) {
                    actionLabel(systemImage: "link",
                                title: "Share Link Only")
                }
                .buttonStyle(.bordered)

                // Plain-text token. Friends paste this into Library → ⋯ →
                // Paste Code. Always works — no app install or deep-link
                // routing required to deliver it.
                ShareLink(
                    item: shareToken,
                    subject: Text(recipe.name),
                    message: Text("Paste this code into Tincta → ⋯ → Paste Code")
                ) {
                    actionLabel(systemImage: "doc.on.doc",
                                title: "Share Code (Text)")
                }
                .buttonStyle(.bordered)

                #if canImport(UIKit)
                Button {
                    UIPasteboard.general.string = shareToken
                    copiedToken = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        copiedToken = false
                    }
                } label: {
                    actionLabel(
                        systemImage: copiedToken ? "checkmark" : "clipboard",
                        title: copiedToken ? "Copied to Clipboard" : "Copy Code"
                    )
                }
                .buttonStyle(.bordered)
                #endif
            } else if let encodingError {
                Text(encodingError)
                    .font(.tinctaBody(14))
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView("Preparing share…")
                    .font(.tinctaBody(14))
                    .padding(.top, 8)
            }
        }
    }

    private func actionLabel(systemImage: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
            Text(title).font(.tinctaUILabel(15))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: - Rendering

    @MainActor
    private func renderAssets() async {
        // Encode the link first; if this fails the share has nothing useful
        // to offer beyond the bare image, but we still try to render it.
        do {
            let token = try TransferCodec.encode(transfer: RecipeTransfer(
                recipes: [RecipePayload(recipe: recipe)]
            ))
            shareToken = token
            shareLink = TransferCodec.customSchemeLink(forToken: token)
        } catch {
            encodingError = "Couldn't build a share link: \(error.localizedDescription)"
        }

        // Render the PNG via ImageRenderer. Use a generous fixed width so the
        // result looks good when posted to Instagram, iMessage, etc.
        let renderer = ImageRenderer(content: ShareableRecipeCard(recipe: recipe, width: 1080))
        renderer.scale = max(displayScale, 2)
        renderer.proposedSize = ProposedViewSize(width: 1080, height: nil)

        #if canImport(UIKit)
        if let uiImage = renderer.uiImage {
            let image = Image(uiImage: uiImage)
            let png = uiImage.pngData()
            renderedImage = ShareableImage(image: image, pngData: png)
        }
        #else
        if let cg = renderer.cgImage {
            let image = Image(decorative: cg, scale: renderer.scale)
            renderedImage = ShareableImage(image: image, pngData: nil)
        }
        #endif
    }
}

// MARK: - Helpers

/// Bundles the SwiftUI `Image` (for `SharePreview`) with the raw PNG bytes
/// (for the image-only share variant).
private struct ShareableImage {
    let image: Image
    let pngData: Data?
}

// MARK: - Preview

private struct RecipeShareSheetPreviewHost: View {
    @Query private var recipes: [Recipe]
    var body: some View {
        let recipe = recipes.first ?? Recipe(name: "Sample", backgroundColorHex: "#C66A28")
        RecipeShareSheet(recipe: recipe)
    }
}

#Preview("Share Sheet") {
    let container = TinctaModelContainer.makePreview()
    return RecipeShareSheetPreviewHost()
        .modelContainer(container)
}
