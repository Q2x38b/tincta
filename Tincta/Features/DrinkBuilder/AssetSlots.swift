import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Asset-slot lookup for the drink visualiser.
///
/// Each vessel / ice type / citrus / garnish / extra is given a **canonical
/// asset name**. If a matching image is present in the app bundle's asset
/// catalog (typically `Tincta/Assets.xcassets/DrinkAssets/...`), the asset
/// is rendered; otherwise the procedural SwiftUI fallback is used.
///
/// This lets you drop in higher-quality illustrations later without touching
/// any view code. Recommended royalty-free sources you can license cleanly:
///
/// - **Game-Icons.net** — CC BY 3.0, has many vessel/garnish glyphs.
///   Provide attribution somewhere in About / Settings.
/// - **OpenMoji** — CC BY-SA 4.0, complete set of drink glasses and
///   garnishes as SVG + PNG. Same attribution requirement.
/// - **Streamline Icons (free pack)** — check current MIT-style terms.
/// - **Tabler / Lucide** — MIT licensed, more abstract line icons.
/// - **Iconify** — aggregator; check the per-icon license before shipping.
///
/// Add files to `Tincta/Assets.xcassets/DrinkAssets/` with these exact names.
/// PNG @1x/2x/3x or single-scale PDF both work; SVG support requires Xcode 12+.
enum DrinkAssetSlots {

    static func vesselAssetName(_ v: Vessel) -> String { "vessel_\(v.rawValue)" }
    static func iceAssetName(_ i: IceType) -> String   { "ice_\(i.rawValue)" }
    static func citrusAssetName(_ c: Citrus) -> String { "citrus_\(c.rawValue)" }
    static func garnishAssetName(_ g: Garnish) -> String { "garnish_\(g.rawValue)" }
    static func extraAssetName(_ e: Extra) -> String   { "extra_\(e.rawValue)" }

    /// Returns true if an asset for the given name is present in the bundle.
    /// Used by the slot views to decide between custom asset and fallback.
    static func hasAsset(named name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}

// MARK: - Slot views (with system-symbol fallback before the procedural draw)

/// Vessel slot: prefers user-supplied asset → SF Symbol (where it reads well)
/// → procedural `VesselShape`. The result is sized to the given frame.
struct VesselArt: View {
    let vessel: Vessel
    /// Tint used for SF Symbol / procedural stroke (the asset is rendered
    /// as-is and ignores this).
    let tint: Color

    var body: some View {
        let assetName = DrinkAssetSlots.vesselAssetName(vessel)
        if DrinkAssetSlots.hasAsset(named: assetName) {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let symbol = systemSymbolName {
            Image(systemName: symbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
        } else {
            VesselShape(vessel: vessel)
                .stroke(tint, lineWidth: 1.4)
        }
    }

    /// SF Symbol that's a faithful representation of the vessel, if any.
    /// Apple's wineglass/mug/cup glyphs are high-quality and beat the
    /// procedural drawing for those specific shapes.
    private var systemSymbolName: String? {
        switch vessel {
        case .wine:         return "wineglass"
        case .copperMug:    return "mug"
        case .tiki:         return "cup.and.saucer"
        // SF Symbols doesn't yet have a true rocks/collins/martini/coupe
        // glyph that beats the procedural shape — fall through to fallback.
        default:            return nil
        }
    }
}

struct IceArt: View {
    let ice: IceType

    var body: some View {
        let assetName = DrinkAssetSlots.iceAssetName(ice)
        if DrinkAssetSlots.hasAsset(named: assetName) {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            IceLayerView(ice: ice)
        }
    }
}

struct CitrusArt: View {
    let citrus: Citrus

    var body: some View {
        let assetName = DrinkAssetSlots.citrusAssetName(citrus)
        if DrinkAssetSlots.hasAsset(named: assetName) {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            CitrusView(citrus: citrus)
        }
    }
}

struct GarnishArt: View {
    let garnish: Garnish

    var body: some View {
        let assetName = DrinkAssetSlots.garnishAssetName(garnish)
        if DrinkAssetSlots.hasAsset(named: assetName) {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            GarnishView(garnish: garnish)
        }
    }
}
