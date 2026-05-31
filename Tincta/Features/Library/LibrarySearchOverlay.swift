import SwiftUI

/// Inline search bar that slides in from the top of the Library when the user
/// performs a pull-down on the card stack. Filters across recipe name,
/// ingredient names, and group tags.
struct LibrarySearchOverlay: View {
    @Binding var searchText: String
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.tinctaInk.opacity(0.55))

            TextField("Search recipes, ingredients, tags", text: $searchText)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .font(.tinctaBody(16))
                .foregroundStyle(Color.tinctaInk)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.tinctaInk.opacity(0.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button("Cancel", action: onCancel)
                .font(.tinctaUILabel(13))
                .foregroundStyle(Color.tinctaInk)
                .accessibilityLabel("Cancel search")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.tinctaGlassStroke, lineWidth: 0.7)
        )
        .shadow(color: Color.tinctaShadow, radius: 12, x: 0, y: 4)
        .padding(.horizontal, 18)
        .onAppear { isFocused = true }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    ZStack {
        Color.tinctaParchment.ignoresSafeArea()
        VStack {
            LibrarySearchOverlay(searchText: .constant("whiskey"), onCancel: {})
            Spacer()
        }
        .padding(.top, 64)
    }
}
