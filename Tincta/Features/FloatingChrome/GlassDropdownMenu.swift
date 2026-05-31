import SwiftUI

/// Reusable popover-style dropdown rendered in Tincta's glass aesthetic.
///
/// Usage:
/// ```
/// @State private var menuOpen = false
/// GlassButton(systemImage: "ellipsis") { menuOpen.toggle() }
///     .glassDropdown(isPresented: $menuOpen, items: [...])
/// ```
///
/// The menu anchors itself to the trailing edge of its host view and presents
/// items in a rounded glass panel with a soft scale + fade transition. The
/// caller is responsible for owning the `isPresented` binding.
public struct GlassDropdownMenu: View {
    let items: [GlassMenuItem]
    @Binding var isPresented: Bool

    public init(items: [GlassMenuItem], isPresented: Binding<Bool>) {
        self.items = items
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                row(item)
                if idx < items.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.12))
                        .padding(.horizontal, 12)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 220, alignment: .leading)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.tinctaGlassStroke, lineWidth: 0.7)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.tinctaShadow, radius: 22, x: 0, y: 12)
    }

    @ViewBuilder
    private func row(_ item: GlassMenuItem) -> some View {
        Button {
            TinctaHaptics.selection()
            isPresented = false
            item.action()
        } label: {
            HStack(spacing: 12) {
                if let symbol = item.systemImage {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 22, alignment: .center)
                }
                Text(item.label)
                    .font(.tinctaBody(15))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(rowTint(item))
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
    }

    private func rowTint(_ item: GlassMenuItem) -> Color {
        if item.isDestructive { return Color(hex: "#E5484D") }
        return item.tint ?? .primary
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .glassEffect(.regular,
                         in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Anchored presentation helper

public extension View {
    /// Presents a `GlassDropdownMenu` anchored to the trailing edge of the
    /// receiver. The dropdown is dismissed on item selection or by tapping
    /// outside its bounds.
    func glassDropdown(
        isPresented: Binding<Bool>,
        alignment: Alignment = .topTrailing,
        items: [GlassMenuItem]
    ) -> some View {
        modifier(GlassDropdownAnchor(
            isPresented: isPresented,
            alignment: alignment,
            items: items
        ))
    }
}

private struct GlassDropdownAnchor: ViewModifier {
    @Binding var isPresented: Bool
    let alignment: Alignment
    let items: [GlassMenuItem]

    func body(content: Content) -> some View {
        content
            .overlay(alignment: dropdownAlignment) {
                if isPresented {
                    GlassDropdownMenu(items: items, isPresented: $isPresented)
                        .padding(.top, 64)
                        .padding(.trailing, 4)
                        .transition(
                            .scale(scale: 0.92, anchor: .topTrailing)
                                .combined(with: .opacity)
                        )
                        .zIndex(10)
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isPresented)
            .background(
                // Tap-outside-to-dismiss scrim.
                Group {
                    if isPresented {
                        Color.black.opacity(0.0001)
                            .ignoresSafeArea()
                            .onTapGesture { isPresented = false }
                    }
                }
            )
    }

    private var dropdownAlignment: Alignment {
        // For now we anchor top-trailing; spec only requires the canonical
        // menu position. Future callers can extend by reading `alignment`.
        alignment
    }
}

#Preview("Glass dropdown over background") {
    DropdownPreviewHarness()
}

private struct DropdownPreviewHarness: View {
    @State private var open = true
    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [Color(hex: "#5B6E55"), Color(hex: "#1F2A1F")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            GlassButton(systemImage: "ellipsis") { open.toggle() }
                .padding(20)
                .glassDropdown(
                    isPresented: $open,
                    items: [
                        GlassMenuItem(label: "Settings", systemImage: "gearshape") {},
                        GlassMenuItem(label: "Export Library", systemImage: "square.and.arrow.up") {},
                        GlassMenuItem(label: "About", systemImage: "info.circle") {},
                        GlassMenuItem(label: "Delete Recipe", systemImage: "trash", isDestructive: true) {}
                    ]
                )
        }
    }
}
