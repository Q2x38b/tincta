import SwiftUI

/// A single ingredient row in the editor. Collapsed by default: tap to expand
/// the inline `QtyWheelPicker` and name field. Designed to be embedded inside
/// a SwiftUI `List` so reorder/delete affordances come for free.
struct IngredientRow: View {
    @Binding var draft: IngredientDraft
    let isExpanded: Bool
    let foreground: Color
    let onToggle: () -> Void

    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Collapsed line — always visible. Tap toggles expansion.
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    IngredientLineText(
                        quantity: Ingredient.formatQuantity(
                            whole: draft.quantityWhole,
                            fraction: draft.fraction
                        ),
                        unit: draft.unit.display(forAmount: draft.amount),
                        name: draft.name.isEmpty ? "INGREDIENT" : draft.name,
                        pointSize: 22
                    )
                    .foregroundStyle(foreground)
                    .opacity(draft.name.isEmpty && !isExpanded ? 0.55 : 1.0)

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(foreground.opacity(0.7))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 14) {
                    // Name field
                    TextField("", text: $draft.name, prompt:
                        Text("INGREDIENT NAME")
                            .foregroundStyle(foreground.opacity(0.45))
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($nameFocused)
                    .font(.tinctaIngredient(22))
                    .foregroundStyle(foreground)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(foreground.opacity(0.10))
                    )

                    QtyWheelPicker(
                        quantityWhole: $draft.quantityWhole,
                        fraction: $draft.fraction,
                        unit: $draft.unit,
                        foreground: foreground
                    )
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear { nameFocused = draft.name.isEmpty }
            }
        }
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }
}

private extension IngredientDraft {
    var amount: Double { Double(quantityWhole) + (fraction?.value ?? 0) }
}

#Preview {
    struct Harness: View {
        @State var draft = IngredientDraft(
            quantityWhole: 2,
            fraction: nil,
            unit: .oz,
            name: "Bourbon"
        )
        @State var expanded = true
        var body: some View {
            IngredientRow(
                draft: $draft,
                isExpanded: expanded,
                foreground: .white,
                onToggle: { expanded.toggle() }
            )
            .padding()
            .background(Color(hex: "#8A9F76"))
        }
    }
    return Harness()
}
