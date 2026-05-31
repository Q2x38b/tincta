import SwiftUI

/// One row in a `GlassDropdownMenu`. Pure value type so callers can construct
/// menus declaratively without holding references to view state.
public struct GlassMenuItem: Identifiable {
    public let id: UUID
    public let label: String
    public let systemImage: String?
    /// Optional tint override for the row (icon + label). Defaults to ink/parchment.
    public let tint: Color?
    /// Marks the row as a destructive action — rendered in red.
    public let isDestructive: Bool
    public let action: () -> Void

    public init(
        id: UUID = UUID(),
        label: String,
        systemImage: String? = nil,
        tint: Color? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.label = label
        self.systemImage = systemImage
        self.tint = tint
        self.isDestructive = isDestructive
        self.action = action
    }
}
