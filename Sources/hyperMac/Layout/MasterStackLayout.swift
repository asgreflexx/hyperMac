import CoreGraphics
import AppKit

/// Master + Side Stack layout.
///
/// - First window = master, occupies `masterRatio` of screen width.
/// - Remaining windows = stack, split equally in the right portion.
/// - If only 1 window: full screen.
final class MasterStackLayout: Layout {
    var masterRatio: CGFloat

    init(masterRatio: CGFloat = 0.55) {
        self.masterRatio = masterRatio
    }

    func calculate(
        windows: [ManagedWindow],
        in screenRect: CGRect,
        gaps: NSEdgeInsets,
        windowGap: CGFloat
    ) -> [UUID: CGRect] {
        guard !windows.isEmpty else { return [:] }

        let outerRect = CGRect(
            x: screenRect.minX + gaps.left,
            y: screenRect.minY + gaps.top,
            width: screenRect.width - gaps.left - gaps.right,
            height: screenRect.height - gaps.top - gaps.bottom
        )

        var result: [UUID: CGRect] = [:]

        if windows.count == 1 {
            result[windows[0].id] = outerRect
            return result
        }

        let master = windows[0]
        let stack = Array(windows.dropFirst())

        let masterWidth = (outerRect.width * masterRatio) - (windowGap / 2)
        let stackX = outerRect.minX + masterWidth + windowGap
        let stackWidth = outerRect.width - masterWidth - windowGap

        let masterRect = CGRect(
            x: outerRect.minX,
            y: outerRect.minY,
            width: masterWidth,
            height: outerRect.height
        )
        result[master.id] = masterRect

        let stackSlotHeight = (outerRect.height - CGFloat(stack.count - 1) * windowGap) / CGFloat(stack.count)
        for (i, window) in stack.enumerated() {
            let y = outerRect.minY + CGFloat(i) * (stackSlotHeight + windowGap)
            result[window.id] = CGRect(x: stackX, y: y, width: stackWidth, height: stackSlotHeight)
        }

        return result
    }
}
