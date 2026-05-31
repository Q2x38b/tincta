import SwiftUI

/// Three-wheel inline picker for editing an ingredient's quantity: a whole
/// number (0-12), an optional fraction, and the unit. Designed to live inside
/// the expanded `IngredientRow`.
struct QtyWheelPicker: View {
    @Binding var quantityWhole: Int
    @Binding var fraction: Fraction?
    @Binding var unit: Unit

    /// 0...12, the whole-number choices on the leftmost barrel.
    private let wholeNumbers: [Int] = Array(0...12)

    /// Fraction choices including a "no fraction" sentinel (-1).
    private let fractionOptions: [Fraction?] = [nil] + Fraction.allCases

    /// Tint used for the wheel selection bar — matches the recipe's foreground.
    let foreground: Color

    var body: some View {
        HStack(spacing: 0) {
            Picker("Whole", selection: $quantityWhole) {
                ForEach(wholeNumbers, id: \.self) { n in
                    Text("\(n)")
                        .font(.tinctaIngredient(22))
                        .foregroundStyle(foreground)
                        .tag(n)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("Fraction", selection: fractionBinding) {
                ForEach(0..<fractionOptions.count, id: \.self) { idx in
                    Group {
                        if let f = fractionOptions[idx] {
                            Text(f.display)
                        } else {
                            Text("–")
                        }
                    }
                    .font(.tinctaIngredient(22))
                    .foregroundStyle(foreground)
                    .tag(idx)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("Unit", selection: $unit) {
                ForEach(Unit.allCases) { u in
                    Text(u.display.isEmpty ? "—" : u.display)
                        .font(.tinctaIngredient(18))
                        .foregroundStyle(foreground)
                        .tag(u)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(height: 140)
    }

    /// Bridges the optional-fraction binding to an integer index for the Picker.
    private var fractionBinding: Binding<Int> {
        Binding(
            get: {
                guard let f = fraction else { return 0 }
                return (fractionOptions.firstIndex(where: { $0 == f })) ?? 0
            },
            set: { newIdx in
                fraction = fractionOptions[newIdx]
            }
        )
    }
}

#Preview {
    struct Harness: View {
        @State var whole = 1
        @State var frac: Fraction? = .half
        @State var unit: Unit = .oz
        var body: some View {
            QtyWheelPicker(
                quantityWhole: $whole,
                fraction: $frac,
                unit: $unit,
                foreground: .white
            )
            .padding()
            .background(Color(hex: "#8A9F76"))
        }
    }
    return Harness()
}
