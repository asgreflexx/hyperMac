import AppKit

/// Dispatches layout calculation to the active Layout implementation.
final class LayoutEngine {
    static let shared = LayoutEngine()

    var bspLayout = BSPLayout()
    var masterStackLayout = MasterStackLayout()

    private var activeLayoutName: [String: String] = [:]  // keyed by screen ID

    private init() {}

    // MARK: - Active Layout

    func activeLayout(for screen: NSScreen) -> any Layout {
        let sid = WorkspaceManager.shared.screenID(screen)
        let name = activeLayoutName[sid] ?? "bsp"
        return layoutByName(name)
    }

    private func layoutByName(_ name: String) -> any Layout {
        switch name {
        case "masterstack": return masterStackLayout
        default: return bspLayout
        }
    }

    func setLayout(_ name: String, for screen: NSScreen) {
        let sid = WorkspaceManager.shared.screenID(screen)
        activeLayoutName[sid] = name
    }

    func getActiveLayoutName(for screen: NSScreen) -> String {
        let sid = WorkspaceManager.shared.screenID(screen)
        return activeLayoutName[sid] ?? "bsp"
    }

    func cycleLayout(for screen: NSScreen) {
        let current = getActiveLayoutName(for: screen)
        let next = current == "bsp" ? "masterstack" : "bsp"
        setLayout(next, for: screen)
        print("[LayoutEngine] Layout cycled to '\(next)' on \(WorkspaceManager.shared.screenID(screen))")
    }

    // MARK: - Calculate

    func calculate(
        windows: [ManagedWindow],
        screen: NSScreen,
        gaps: NSEdgeInsets,
        windowGap: CGFloat
    ) -> [UUID: CGRect] {
        let layout = activeLayout(for: screen)
        // Use visibleFrame (excludes menu bar and Dock) in NSScreen coordinates
        let rect = screen.visibleFrame
        return layout.calculate(windows: windows, in: rect, gaps: gaps, windowGap: windowGap)
    }

    // MARK: - Apply Frames

    func apply(frames: [UUID: CGRect], to windows: [ManagedWindow]) {
        for window in windows {
            guard let frame = frames[window.id] else { continue }
            window.axWrapper.setFrame(frame)
        }
    }
}
