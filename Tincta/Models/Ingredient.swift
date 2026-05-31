import Foundation
import SwiftData

@Model
final class Ingredient {
    @Attribute(.unique) var id: UUID
    var quantityWhole: Int
    var fractionRaw: String?
    var unitRaw: String
    var name: String
    var order: Int
    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        quantityWhole: Int = 0,
        fraction: Fraction? = nil,
        unit: Unit = .oz,
        name: String,
        order: Int
    ) {
        self.id = id
        self.quantityWhole = quantityWhole
        self.fractionRaw = fraction?.rawValue
        self.unitRaw = unit.rawValue
        self.name = name
        self.order = order
    }

    var fraction: Fraction? {
        get { fractionRaw.flatMap(Fraction.init(rawValue:)) }
        set { fractionRaw = newValue?.rawValue }
    }

    var unit: Unit {
        get { Unit(rawValue: unitRaw) ?? .oz }
        set { unitRaw = newValue.rawValue }
    }

    /// Numeric amount as whole + fraction. For piece units (`count`, `leaf`),
    /// this is the raw count; for volumetric units it's the amount in `unit`.
    var amount: Double {
        Double(quantityWhole) + (fraction?.value ?? 0)
    }

    /// "2 oz BOURBON" with a soft breakable hairline space between number and unit.
    var displayLine: String {
        let qty = Self.formatQuantity(whole: quantityWhole, fraction: fraction)
        let unitWord = unit.display(forAmount: amount)
        if unitWord.isEmpty {
            return "\(qty) \(name.uppercased())"
        }
        return "\(qty) \(unitWord) \(name.uppercased())"
    }

    static func formatQuantity(whole: Int, fraction: Fraction?) -> String {
        switch (whole, fraction) {
        case (0, .some(let f)):  return f.display
        case (let w, .none):     return "\(w)"
        case (let w, .some(let f)): return "\(w) \(f.display)"
        }
    }
}
