import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Asset-slot lookup for the drink visualiser.
///
/// Each vessel / ice / citrus / garnish / extra has a canonical asset name
/// (e.g. `vessel_rocks`). If a matching image is present in the bundle,
/// the asset wins; otherwise we fall back to SF Symbols where they fit,
/// then to the procedural SwiftUI shape.
///
/// The bundled Phosphor SVGs use `stroke="currentColor"` — they're template
/// images. So the slot views below all apply `.renderingMode(.template)` +
/// `.foregroundStyle(tint)` so the strokes actually pick up colour. Without
/// the tint the SVGs would render as transparent line art = invisible =
/// silently fall back to procedural, which is what was happening before.
enum DrinkAssetSlots {

    static func vesselAssetName(_ v: Vessel) -> String { "vessel_\(v.rawValue)" }
    static func iceAssetName(_ i: IceType) -> String   { "ice_\(i.rawValue)" }
    static func citrusAssetName(_ c: Citrus) -> String { "citrus_\(c.rawValue)" }
    static func garnishAssetName(_ g: Garnish) -> String { "garnish_\(g.rawValue)" }
    static func extraAssetName(_ e: Extra) -> String   { "extra_\(e.rawValue)" }

    static func hasAsset(named name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}

// MARK: - Tinted template asset

/// Shared helper that loads the named asset as a template image, tinted
/// with the caller's colour. Returns nil if the asset isn't in the bundle.
private struct TemplateAsset: View {
    let name: String
    let tint: Color

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(tint)
    }
}

// MARK: - Vessel

struct VesselArt: View {
    let vessel: Vessel
    let tint: Color

    var body: some View {
        let asset = DrinkAssetSlots.vesselAssetName(vessel)
        if DrinkAssetSlots.hasAsset(named: asset) {
            TemplateAsset(name: asset, tint: tint)
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

    private var systemSymbolName: String? {
        switch vessel {
        case .wine:         return "wineglass"
        case .copperMug:    return "mug"
        case .tiki:         return "cup.and.saucer"
        default:            return nil
        }
    }
}

// MARK: - Ice

struct IceArt: View {
    let ice: IceType
    var tint: Color = .white

    var body: some View {
        let asset = DrinkAssetSlots.iceAssetName(ice)
        if DrinkAssetSlots.hasAsset(named: asset) {
            TemplateAsset(name: asset, tint: tint)
        } else {
            IceLayerView(ice: ice)
        }
    }
}

// MARK: - Citrus

struct CitrusArt: View {
    let citrus: Citrus
    var tint: Color = .white

    var body: some View {
        let asset = DrinkAssetSlots.citrusAssetName(citrus)
        if DrinkAssetSlots.hasAsset(named: asset) {
            TemplateAsset(name: asset, tint: tint)
        } else {
            CitrusView(citrus: citrus)
        }
    }
}

// MARK: - Garnish

struct GarnishArt: View {
    let garnish: Garnish
    var tint: Color = .white

    var body: some View {
        let asset = DrinkAssetSlots.garnishAssetName(garnish)
        if DrinkAssetSlots.hasAsset(named: asset) {
            TemplateAsset(name: asset, tint: tint)
        } else {
            GarnishView(garnish: garnish)
        }
    }
}

// MARK: - Extra

struct ExtraArt: View {
    let extra: Extra
    var tint: Color = .white

    var body: some View {
        let asset = DrinkAssetSlots.extraAssetName(extra)
        if DrinkAssetSlots.hasAsset(named: asset) {
            TemplateAsset(name: asset, tint: tint)
        } else {
            // Existing fallback view name from DrinkPreviewView.
            EmptyView()
        }
    }
}
