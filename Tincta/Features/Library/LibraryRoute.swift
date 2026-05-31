import Foundation

/// Navigation routes presented from the Library card stack. Integration on
/// `main` wires the destination views for both cases; this worktree only
/// provides a placeholder detail screen for previewing the push.
public enum LibraryRoute: Hashable {
    case detail(UUID)
    case editor(UUID?)
}
