import Foundation
import SwiftData

/// Configures the rendered drink graphic shown in the Recipe Detail view and the
/// Drink Builder live preview. One per Recipe.
@Model
final class DrinkLook {
    @Attribute(.unique) var id: UUID

    var vesselRaw: String
    /// Hex like `#C66A28`. Empty string means "no liquid" (the striped/clear swatch).
    var drinkColorHex: String
    var iceRaw: String?
    var citrusRaw: [String]
    var garnishRaw: [String]
    var extrasRaw: [String]

    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        vessel: Vessel = .rocks,
        drinkColorHex: String = "",
        ice: IceType? = nil,
        citrus: [Citrus] = [],
        garnishes: [Garnish] = [],
        extras: [Extra] = []
    ) {
        self.id = id
        self.vesselRaw = vessel.rawValue
        self.drinkColorHex = drinkColorHex
        self.iceRaw = ice?.rawValue
        self.citrusRaw = citrus.map(\.rawValue)
        self.garnishRaw = garnishes.map(\.rawValue)
        self.extrasRaw = extras.map(\.rawValue)
    }

    var vessel: Vessel {
        get { Vessel(rawValue: vesselRaw) ?? .rocks }
        set { vesselRaw = newValue.rawValue }
    }

    var ice: IceType? {
        get { iceRaw.flatMap(IceType.init(rawValue:)) }
        set { iceRaw = newValue?.rawValue }
    }

    var citrus: [Citrus] {
        get { citrusRaw.compactMap(Citrus.init(rawValue:)) }
        set { citrusRaw = newValue.map(\.rawValue) }
    }

    var garnishes: [Garnish] {
        get { garnishRaw.compactMap(Garnish.init(rawValue:)) }
        set { garnishRaw = newValue.map(\.rawValue) }
    }

    var extras: [Extra] {
        get { extrasRaw.compactMap(Extra.init(rawValue:)) }
        set { extrasRaw = newValue.map(\.rawValue) }
    }

    /// `true` when the drink-color swatch is the "empty/striped" sentinel.
    var hasLiquid: Bool { !drinkColorHex.isEmpty }
}
