import XCTest
@testable import hyperMac

final class MasterStackLayoutTests: XCTestCase {
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let noGaps = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    let gap: CGFloat = 0

    // MARK: - Helpers

    private func makeWindow(order: Int) -> ManagedWindow {
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
        let layout = MasterStackLayout(masterRatio: 0.55)
        let window = makeWindow(order: 0)
        let result = layout.calculate(windows: [window], in: screen, gaps: noGaps, windowGap: gap)
        XCTAssertEqual(result[window.id], screen)
    }

    func testTwoWindowsMasterStack() {
        let layout = MasterStackLayout(masterRatio: 0.55)
        let master = makeWindow(order: 0)
        let stack1 = makeWindow(order: 1)
        let result = layout.calculate(windows: [master, stack1], in: screen, gaps: noGaps, windowGap: gap)

        let masterRect = result[master.id]!
        let stackRect = result[stack1.id]!

        XCTAssertEqual(masterRect.width, 1920 * 0.55, accuracy: 1)
        XCTAssertEqual(stackRect.width, 1920 * 0.45, accuracy: 1)
        XCTAssertEqual(masterRect.height, 1080)
        XCTAssertEqual(stackRect.height, 1080)
        XCTAssertEqual(masterRect.minX, 0)
        XCTAssertEqual(stackRect.minX, 1920 * 0.55, accuracy: 1)
    }

    func testThreeWindowsStackDividedEqually() {
        let layout = MasterStackLayout(masterRatio: 0.5)
        let master = makeWindow(order: 0)
        let s1 = makeWindow(order: 1)
        let s2 = makeWindow(order: 2)
        let result = layout.calculate(windows: [master, s1, s2], in: screen, gaps: noGaps, windowGap: gap)

        let r1 = result[s1.id]!
        let r2 = result[s2.id]!

        XCTAssertEqual(r1.height, 540, accuracy: 1)
        XCTAssertEqual(r2.height, 540, accuracy: 1)
        XCTAssertEqual(r1.minY, 0)
        XCTAssertEqual(r2.minY, 540, accuracy: 1)
    }

    func testFourWindowsStackDividedEqually() {
        let layout = MasterStackLayout(masterRatio: 0.55)
        let windows = (0..<4).map { makeWindow(order: $0) }
        let result = layout.calculate(windows: windows, in: screen, gaps: noGaps, windowGap: gap)

        XCTAssertEqual(result.count, 4)

        let stackWindows = windows.dropFirst().map { result[$0.id]! }
        let expectedHeight = 1080.0 / 3.0
        for rect in stackWindows {
            XCTAssertEqual(rect.height, expectedHeight, accuracy: 1)
        }
    }

    func testGapsApplied() {
        let layout = MasterStackLayout(masterRatio: 0.55)
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
        let layout = MasterStackLayout()
        let result = layout.calculate(windows: [], in: screen, gaps: noGaps, windowGap: 0)
        XCTAssertTrue(result.isEmpty)
    }

    func testMasterRatioRespected() {
        let ratio: CGFloat = 0.7
        let layout = MasterStackLayout(masterRatio: ratio)
        let master = makeWindow(order: 0)
        let stack = makeWindow(order: 1)
        let result = layout.calculate(windows: [master, stack], in: screen, gaps: noGaps, windowGap: gap)

        let masterRect = result[master.id]!
        XCTAssertEqual(masterRect.width, screen.width * ratio, accuracy: 1)
    }
}
