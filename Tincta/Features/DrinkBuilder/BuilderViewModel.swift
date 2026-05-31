import SwiftUI
import Observation

/// Curated palette of liquid hexes presented in the Drink Color row. First entry
/// is the "empty / no liquid" sentinel and renders as a striped swatch.
enum LiquidPalette {
    static let emptyHex = ""

    /// Ordered list of hexes the picker shows. Index 0 is the empty sentinel.
    static let hexes: [String] = [
        emptyHex,
        TinctaPalette.amberLiquid.hex,     // #C8843B
        TinctaPalette.paleLiquid.hex,      // #E8E2C0
        "#965D2D",   // amber 700 — rich amber
        "#7B3F22",   // deep brown
        "#5E3F4F",   // plum
        "#A85469",   // berry
        "#C76A5A",   // coral / red
        "#3F5C5F",   // deep teal
        "#588A8E",   // teal
        "#8A9F76",   // sage
        "#D8C76A",   // gold
        "#F4E6A1",   // pale yellow
        "#B68F88",   // mauve
        "#3A3640",   // charcoal
    ]
}

/// Live, observable buffer of a DrinkLook that the builder mutates as the user
/// taps options. Persisted back to the bound DrinkLook on `commit()`.
@Observable
final class BuilderViewModel {
    var vessel: Vessel
    var drinkColorHex: String
    var ice: IceType
    var citrus: [Citrus]
    var garnishes: [Garnish]
    var extras: [Extra]

    /// Source DrinkLook this builder is editing.
    private weak var source: DrinkLook?

    init(look: DrinkLook?) {
        self.source = look
        self.vessel = look?.vessel ?? .rocks
        self.drinkColorHex = look?.drinkColorHex ?? ""
        self.ice = look?.ice ?? .none
        self.citrus = look?.citrus ?? []
        self.garnishes = look?.garnishes ?? []
        self.extras = look?.extras ?? []
    }

    /// A live, ephemeral DrinkLook used to feed `DrinkPreviewView`. Not inserted
    /// into the model context — it's a transient value used only for rendering.
    var stagedLook: DrinkLook {
        DrinkLook(
            vessel: vessel,
            drinkColorHex: drinkColorHex,
            ice: ice == .none ? nil : ice,
            citrus: citrus,
            garnishes: garnishes,
            extras: extras
        )
    }

    /// Writes the staged values back through to the bound `DrinkLook` from the
    /// model. Called when the user taps DONE.
    func commit() {
        guard let source else { return }
        source.vessel = vessel
        source.drinkColorHex = drinkColorHex
        source.ice = ice == .none ? nil : ice
        source.citrus = citrus
        source.garnishes = garnishes
        source.extras = extras
    }

    // MARK: - Toggle helpers

    func toggle(_ c: Citrus) {
        if let idx = citrus.firstIndex(of: c) {
            citrus.remove(at: idx)
        } else {
            citrus.append(c)
        }
    }

    func toggle(_ g: Garnish) {
        if let idx = garnishes.firstIndex(of: g) {
            garnishes.remove(at: idx)
        } else {
            garnishes.append(g)
        }
    }

    func toggle(_ e: Extra) {
        if let idx = extras.firstIndex(of: e) {
            extras.remove(at: idx)
        } else {
            extras.append(e)
        }
    }
}
