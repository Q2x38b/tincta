import SwiftUI

/// One item rendered inside `MenuDropdownView`.
public struct MenuDropdownItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let systemImage: String
    public let role: Role
    public let action: () -> Void

    public enum Role {
        case standard
        case destructive
    }

    public init(title: String,
                systemImage: String,
                role: Role = .standard,
                action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }
}

/// Glass-styled dropdown anchored from the top-right ellipsis button. The host
/// view is responsible for toggling `isPresented` (usually a `@State` bool on
/// the Library screen) and stacking the dropdown above the rest of the UI via
/// `.overlay(alignment: .topTrailing)`.
///
/// On iOS 26 the panel uses a true Liquid Glass effect; older runtimes fall
/// back to `.ultraThinMaterial`. The dropdown has its own dismissal scrim so
/// tapping outside closes it.
public struct MenuDropdownView: View {
    @Binding var isPresented: Bool

    let onSettings: () -> Void
    let onShare: () -> Void
    let onImport: () -> Void
    let onAbout: () -> Void
    let onScan: (RecipeImportSource) -> Void

    public init(isPresented: Binding<Bool>,
                onSettings: @escaping () -> Void,
                onShare: @escaping () -> Void = {},
                onImport: @escaping () -> Void = {},
                onAbout: @escaping () -> Void,
                onScan: @escaping (RecipeImportSource) -> Void = { _ in }) {
        self._isPresented = isPresented
        self.onSettings = onSettings
        self.onShare = onShare
        self.onImport = onImport
        self.onAbout = onAbout
        self.onScan = onScan
    }

    private var items: [MenuDropdownItem] {
        [
            .init(title: "Scan with Camera", systemImage: "camera") {
                close { onScan(.camera) }
            },
            .init(title: "Pick from Photos", systemImage: "photo.on.rectangle") {
                close { onScan(.photos) }
            },
            .init(title: "Choose Files", systemImage: "folder") {
                close { onScan(.files) }
            },
            .init(title: "Settings", systemImage: "gearshape") {
                close { onSettings() }
            },
            .init(title: "Share",    systemImage: "square.and.arrow.up") {
                close { onShare() }
            },
            .init(title: "Import",   systemImage: "square.and.arrow.down") {
                close { onImport() }
            },
            .init(title: "About",    systemImage: "info.circle") {
                close { onAbout() }
            },
        ]
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Tap-to-dismiss scrim. Transparent but blocks hits.
            if isPresented {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .transition(.opacity)
            }

            if isPresented {
                panel
                    .frame(width: 240)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.94, anchor: .topTrailing)
                                .combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isPresented)
        .allowsHitTesting(isPresented)
    }

    @ViewBuilder
    private var panel: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { (index, item) in
                Button(action: item.action) {
                    HStack(spacing: 14) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 22, alignment: .center)
                            .foregroundStyle(
                                item.role == .destructive ? Color.red : Color.white
                            )
                        Text(item.title)
                            .font(.tinctaUILabel())
                            .foregroundStyle(
                                item.role == .destructive ? Color.red : Color.white
                            )
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens \(item.title)"))

                if index < items.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.tinctaGlassStroke, lineWidth: 0.7)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.tinctaShadow, radius: 22, x: 0, y: 12)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .glassEffect(.clear,
                         in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func close(_ then: (() -> Void)? = nil) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isPresented = false
        }
        // Defer the action until the dismissal animation has had a beat.
        if let then {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { then() }
        }
    }
}

// MARK: - Preview

private struct MenuDropdownPreviewHost: View {
    @State private var open = true
    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color(hex: "#F4EFE6"), Color(hex: "#E7DDC9")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                Text("Library").font(.tinctaDisplay())
                Text("Tap the dots to toggle the menu.")
                    .font(.tinctaBody())
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // The actual button + dropdown stack
            VStack(alignment: .trailing, spacing: 0) {
                GlassButton(systemImage: "ellipsis", tint: .tinctaInk) {
                    withAnimation { open.toggle() }
                }
                .padding(.top, 16)
                .padding(.trailing, 16)

                MenuDropdownView(
                    isPresented: $open,
                    onSettings: { print("settings") },
                    onShare:    { print("share") },
                    onImport:   { print("import") },
                    onAbout:    { print("about") }
                )
            }
        }
    }
}

#Preview("Menu Dropdown") {
    MenuDropdownPreviewHost()
}
