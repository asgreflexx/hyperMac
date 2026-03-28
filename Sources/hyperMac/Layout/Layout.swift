import CoreGraphics
import AppKit

/// Direction enum used for focus/window movement
enum Direction {
    case left, right, up, down
}

/// Protocol all layout engines must conform to.
protocol Layout {
    /// Calculate frame for each window.
    /// - Parameters:
    ///   - windows: Tiled (non-floating) windows to lay out.
    ///   - screenRect: Available screen rect (full usable area).
    ///   - gaps: Outer edge gaps (top/left/bottom/right insets from screen edge).
    ///   - windowGap: Gap between adjacent windows.
    /// - Returns: Map of window UUID → CGRect in NSScreen coordinates.
    func calculate(
        windows: [ManagedWindow],
        in screenRect: CGRect,
        gaps: NSEdgeInsets,
        windowGap: CGFloat
    ) -> [UUID: CGRect]
}
