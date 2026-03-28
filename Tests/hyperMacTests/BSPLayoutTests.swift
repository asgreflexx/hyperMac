import XCTest
@testable import hyperMac

final class BSPLayoutTests: XCTestCase {
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let noGaps = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    let gap: CGFloat = 0

    // MARK: - Helpers

    private func makeWindow(order: Int) -> ManagedWindow {
        // AXUIElement is not constructable in tests, so we skip real AX.
        // We test the layout math only — windows are identified by UUID.
        let element = AXUIElementCreateSystemWide()
        let wrapper = AXWindowWrapper(element: element, pid: 0)
        return ManagedWindow(
            id: UUID(),
            axWrapper: wrapper,
            isFloating: false,
            lastTiledFrame: nil,
            workspaceID: 1,
            orderIndex: order
        )
    }

    // MARK: - Tests

    func testSingleWindowFillsScreen() {
        let layout = BSPLayout(splitRatio: 0.5)
        let window = makeWindow(order: 0)
        let result = layout.calculate(windows: [window], in: screen, gaps: noGaps, windowGap: gap)
        XCTAssertEqual(result[window.id], screen)
    }

    func testTwoWindowsVerticalSplit() {
        // screen is landscape (1920x1080), so first split is vertical
        let layout = BSPLayout(splitRatio: 0.5)
        let w1 = makeWindow(order: 0)
        let w2 = makeWindow(order: 1)
        let result = layout.calculate(windows: [w1, w2], in: screen, gaps: noGaps, windowGap: gap)

        let r1 = result[w1.id]!
        let r2 = result[w2.id]!

        XCTAssertEqual(r1.minX, 0)
        XCTAssertEqual(r1.width, 960, accuracy: 1)
        XCTAssertEqual(r2.minX, 960, accuracy: 1)
        XCTAssertEqual(r2.width, 960, accuracy: 1)
        XCTAssertEqual(r1.height, 1080)
        XCTAssertEqual(r2.height, 1080)
    }

    func testThreeWindowsBSP() {
        let layout = BSPLayout(splitRatio: 0.5)
        let w1 = makeWindow(order: 0)
        let w2 = makeWindow(order: 1)
        let w3 = makeWindow(order: 2)
        let result = layout.calculate(windows: [w1, w2, w3], in: screen, gaps: noGaps, windowGap: gap)

        // w1: left half
        let r1 = result[w1.id]!
        XCTAssertEqual(r1.width, 960, accuracy: 1)
        XCTAssertEqual(r1.height, 1080)

        // w2 + w3 share right half (1920x1080 right half is 960x1080 — portrait → horizontal split)
        let r2 = result[w2.id]!
        let r3 = result[w3.id]!
        XCTAssertEqual(r2.minX, 960, accuracy: 1)
        XCTAssertEqual(r3.minX, 960, accuracy: 1)
        XCTAssertEqual(r2.height, 540, accuracy: 1)
        XCTAssertEqual(r3.height, 540, accuracy: 1)
    }

    func testFourWindows() {
        let layout = BSPLayout(splitRatio: 0.5)
        let windows = (0..<4).map { makeWindow(order: $0) }
        let result = layout.calculate(windows: windows, in: screen, gaps: noGaps, windowGap: gap)
        XCTAssertEqual(result.count, 4)

        // All windows should be within screen bounds
        for (_, rect) in result {
            XCTAssertTrue(screen.contains(rect) || screen.intersects(rect))
            XCTAssertGreaterThan(rect.width, 0)
            XCTAssertGreaterThan(rect.height, 0)
        }
    }

    func testGapsApplied() {
        let layout = BSPLayout(splitRatio: 0.5)
        let window = makeWindow(order: 0)
        let gaps = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        let result = layout.calculate(windows: [window], in: screen, gaps: gaps, windowGap: 0)
        let rect = result[window.id]!

        XCTAssertEqual(rect.minX, 10)
        XCTAssertEqual(rect.minY, 10)
        XCTAssertEqual(rect.width, screen.width - 20, accuracy: 1)
        XCTAssertEqual(rect.height, screen.height - 20, accuracy: 1)
    }

    func testEmptyWindowsReturnsEmpty() {
        let layout = BSPLayout()
        let result = layout.calculate(windows: [], in: screen, gaps: noGaps, windowGap: 0)
        XCTAssertTrue(result.isEmpty)
    }

    func testWindowGapBetweenWindows() {
        let layout = BSPLayout(splitRatio: 0.5)
        let w1 = makeWindow(order: 0)
        let w2 = makeWindow(order: 1)
        let windowGap: CGFloat = 20
        let result = layout.calculate(windows: [w1, w2], in: screen, gaps: noGaps, windowGap: windowGap)

        let r1 = result[w1.id]!
        let r2 = result[w2.id]!
        // Gap between r1.maxX and r2.minX should equal windowGap
        XCTAssertEqual(r2.minX - r1.maxX, windowGap, accuracy: 1)
    }
}
