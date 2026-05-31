import Foundation

/// Splits a free-form `directions` string into numbered steps for display.
///
/// Rule (from the §6 plan): one step per non-empty line separated by `\n`.
/// Wrapping is handled by the SwiftUI Text view; only line breaks create new
/// numbered steps. Leading/trailing whitespace inside a step is trimmed but
/// internal spacing is preserved.
public enum DirectionsRenderer {

    /// A single, numbered step ready to render.
    public struct Step: Identifiable, Hashable {
        public let index: Int  // 1-based
        public let step: String
        public var id: Int { index }
    }

    /// Convert raw multi-line directions to numbered (1-based) steps.
    /// Empty / whitespace-only lines are dropped.
    public static func render(_ raw: String) -> [Step] {
        raw
            .split(whereSeparator: { $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { Step(index: $0.offset + 1, step: $0.element) }
    }
}
