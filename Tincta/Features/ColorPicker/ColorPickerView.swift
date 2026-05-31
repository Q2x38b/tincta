import SwiftUI

/// Full-screen Choose Color sheet (matches Images 6/7/8 of the design mocks).
///
/// Top bar: black band with "< BACK" on the left and "CHOOSE COLOR" centered.
/// Body: a vertical scroll of full-bleed color bands sourced from
/// `TinctaPalette.grouped()`, ordered by family so neighboring bands feel like
/// a hue gradient.
public struct ColorPickerView: View {
    private let initialHex: String
    private let onSelect: (TinctaSwatch) -> Void
    private let onCancel: () -> Void

    @State private var selectedHex: String

    /// Height of each color band in points.
    private let bandHeight: CGFloat = 120

    public init(
        initialHex: String,
        onSelect: @escaping (TinctaSwatch) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialHex = initialHex
        self.onSelect = onSelect
        self.onCancel = onCancel
        _selectedHex = State(initialValue: initialHex.uppercased())
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(orderedSwatches, id: \.id) { swatch in
                        ColorBandRow(
                            swatch: swatch,
                            isSelected: swatch.hex.uppercased() == selectedHex,
                            height: bandHeight
                        ) {
                            handleSelection(swatch)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Color.black

            HStack {
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("BACK")
                            .font(.tinctaUILabel(13))
                            .tracking(1.4)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Spacer()
            }

            Text("CHOOSE COLOR")
                .font(.tinctaUILabel(14))
                .tracking(2.0)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(height: 52)
    }

    // MARK: - Data

    /// Flattened swatch order: family order from `TinctaPalette.grouped()`,
    /// with swatches contiguous within each family.
    private var orderedSwatches: [TinctaSwatch] {
        TinctaPalette.grouped().flatMap { $0.1 }
    }

    // MARK: - Selection

    private func handleSelection(_ swatch: TinctaSwatch) {
        withAnimation(.easeOut(duration: 0.12)) {
            selectedHex = swatch.hex.uppercased()
        }
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
        onSelect(swatch)
    }
}

#if canImport(UIKit)
import UIKit
#endif

#Preview("Rust pre-selected") {
    ColorPickerView(
        initialHex: TinctaPalette.rust.hex,
        onSelect: { _ in },
        onCancel: { }
    )
}
