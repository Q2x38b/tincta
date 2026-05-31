import SwiftUI
import SwiftData

// MARK: - Routes

/// Where an incoming URL wants to take the user. Only `importRecipes` is
/// implemented here; integration code on `main` may extend this enum for other
/// deep-link surfaces.
enum AppRoute: Equatable {
    case importRecipes(RecipeTransfer)
    case unknown
}

/// Pending import surfaced to the UI. Carrying the decoded transfer means the
/// preview sheet can show recipe names without re-decoding the token.
struct ImportPreview: Identifiable, Equatable {
    let id = UUID()
    let transfer: RecipeTransfer

    init(transfer: RecipeTransfer) {
        self.transfer = transfer
    }
}

// MARK: - Router

/// Stateless URL router. Lives in the Sharing feature so other modules can
/// stay ignorant of the deep-link wire format.
enum UniversalLinkRouter {

    /// Resolve a URL into an `AppRoute`. Returns `.unknown` for any URL the
    /// Sharing feature doesn't recognize so the caller can chain other
    /// handlers without throwing.
    static func route(for url: URL) -> AppRoute {
        guard let token = extractToken(from: url) else { return .unknown }
        do {
            let transfer = try TransferCodec.decode(token)
            return .importRecipes(transfer)
        } catch {
            return .unknown
        }
    }

    /// Pulls the base64 token out of either link shape. Public so callers that
    /// only need the raw token (e.g. tests, logging) can use it directly.
    static func extractToken(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        // Universal link: https://tincta.app/r/<token>
        if let host = components.host?.lowercased(),
           host == TransferCodec.universalLinkHost {
            let path = components.path
            if path.hasPrefix(TransferCodec.universalLinkPathPrefix) {
                let token = String(path.dropFirst(TransferCodec.universalLinkPathPrefix.count))
                return token.isEmpty ? nil : token
            }
            return nil
        }

        // Custom scheme: tincta://import?data=<token>
        if components.scheme?.lowercased() == TransferCodec.customScheme {
            // Accept both ?data=... query param and a bare path token for
            // resilience against share extensions that drop query strings.
            if let item = components.queryItems?.first(where: { $0.name == "data" }),
               let value = item.value, !value.isEmpty {
                return value
            }
            let pathToken = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return pathToken.isEmpty ? nil : pathToken
        }

        return nil
    }
}

// MARK: - View modifier

extension View {
    /// Attach to the app root (or any view that should respond to incoming
    /// Tincta share links). Decodes the URL, and when it's an import route,
    /// surfaces an `ImportPreview` via the binding so the caller can present
    /// `ImportPreviewView`.
    func handleTinctaImportLink(
        into context: ModelContext,
        presented: Binding<ImportPreview?>
    ) -> some View {
        modifier(TinctaImportLinkModifier(context: context, presented: presented))
    }
}

private struct TinctaImportLinkModifier: ViewModifier {
    let context: ModelContext
    @Binding var presented: ImportPreview?

    func body(content: Content) -> some View {
        content.onOpenURL { url in
            switch UniversalLinkRouter.route(for: url) {
            case .importRecipes(let transfer):
                presented = ImportPreview(transfer: transfer)
            case .unknown:
                break
            }
        }
    }
}
