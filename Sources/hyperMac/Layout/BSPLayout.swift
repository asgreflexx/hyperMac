import CoreGraphics
import AppKit

/// Binary Space Partitioning layout.
///
/// Recursively splits available space:
/// 1. If 1 window: full rect.
/// 2. Split direction based on aspect ratio (wider → vertical split, taller → horizontal split).
/// 3. First window gets `splitRatio` of the space; remaining windows recurse on the rest.
final class BSPLayout: Layout {
    var splitRatio: CGFloat

    init(splitRatio: CGFloat = 0.5) {
        self.splitRatio = splitRatio
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
        split(windows: windows, in: outerRect, windowGap: windowGap, result: &result)
        return result
    }

    private func split(
        windows: [ManagedWindow],
        in rect: CGRect,
        windowGap: CGFloat,
        result: inout [UUID: CGRect]
    ) {
        guard !windows.isEmpty else { return }

        if windows.count == 1 {
            result[windows[0].id] = rect
            return
        }

        // Balanced split: divide list in half so both sides of every split are used.
        // With 4 windows: W1+W2 on left, W3+W4 on right (rather than W1 alone on left forever).
        let midIndex = windows.count / 2
        let firstGroup = Array(windows[..<midIndex])
        let secondGroup = Array(windows[midIndex...])

        // Split ratio proportional to window count so each window gets equal screen area.
        let ratio = CGFloat(firstGroup.count) / CGFloat(windows.count)

        let splitVertically = rect.width >= rect.height

        if splitVertically {
            let firstWidth = rect.width * ratio - windowGap / 2
            let secondX = rect.minX + firstWidth + windowGap
            let secondWidth = rect.width - firstWidth - windowGap

            split(windows: firstGroup, in: CGRect(x: rect.minX, y: rect.minY, width: firstWidth, height: rect.height), windowGap: windowGap, result: &result)
            split(windows: secondGroup, in: CGRect(x: secondX, y: rect.minY, width: secondWidth, height: rect.height), windowGap: windowGap, result: &result)
        } else {
            let firstHeight = rect.height * ratio - windowGap / 2
            let secondY = rect.minY + firstHeight + windowGap
            let secondHeight = rect.height - firstHeight - windowGap

            split(windows: firstGroup, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: firstHeight), windowGap: windowGap, result: &result)
            split(windows: secondGroup, in: CGRect(x: rect.minX, y: secondY, width: rect.width, height: secondHeight), windowGap: windowGap, result: &result)
        }
    }

    /// Swap two adjacent windows in BSP order. Returns a new ordering of window IDs.
    func swapWindows(windows: [ManagedWindow], direction: Direction, focusedID: UUID) -> [UUID] {
        guard let focusedIndex = windows.firstIndex(where: { $0.id == focusedID }) else {
            return windows.map(\.id)
        }

        var ids = windows.map(\.id)

        switch direction {
        case .left, .up:
            if focusedIndex > 0 {
                ids.swapAt(focusedIndex, focusedIndex - 1)
            }
        case .right, .down:
            if focusedIndex < ids.count - 1 {
                ids.swapAt(focusedIndex, focusedIndex + 1)
            }
        }

        return ids
    }
}
