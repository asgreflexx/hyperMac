import AppKit

/// Represents a single virtual workspace on a specific screen.
final class Workspace {
    let id: Int
    let screen: NSScreen
    var windowIDs: [UUID] = []
    var layoutName: String = "bsp"

    init(id: Int, screen: NSScreen) {
        self.id = id
        self.screen = screen
    }
}

/// Manages virtual workspaces (1–5) per screen.
final class WorkspaceManager {
    static let shared = WorkspaceManager()

    /// workspaces[screenID][workspaceNumber 1-5]
    private var workspaces: [String: [Int: Workspace]] = [:]

    /// Currently active workspace index per screen.
    private var activeWorkspaceIndex: [String: Int] = [:]

    private init() {}

    // MARK: - Setup

    func setup(screens: [NSScreen], defaultLayout: String) {
        for screen in screens {
            let sid = screenID(screen)
            if workspaces[sid] == nil {
                var map: [Int: Workspace] = [:]
                for n in 1...5 {
                    let ws = Workspace(id: n, screen: screen)
                    ws.layoutName = defaultLayout
                    map[n] = ws
                }
                workspaces[sid] = map
                activeWorkspaceIndex[sid] = 1
            }
        }
    }

    // MARK: - Active Workspace

    func activeWorkspace(for screen: NSScreen) -> Workspace? {
        let sid = screenID(screen)
        let idx = activeWorkspaceIndex[sid] ?? 1
        return workspaces[sid]?[idx]
    }

    func switchWorkspace(_ number: Int, on screen: NSScreen) {
        let sid = screenID(screen)
        guard (1...5).contains(number), workspaces[sid] != nil else { return }
        activeWorkspaceIndex[sid] = number
        print("[WorkspaceManager] Switched to workspace \(number) on screen \(sid)")
    }

    // MARK: - Window Assignment

    func addWindow(_ id: UUID, to workspace: Int, on screen: NSScreen) {
        let sid = screenID(screen)
        workspaces[sid]?[workspace]?.windowIDs.append(id)
    }

    func removeWindow(_ id: UUID) {
        for sid in workspaces.keys {
            for wsn in workspaces[sid]!.keys {
                workspaces[sid]![wsn]!.windowIDs.removeAll { $0 == id }
            }
        }
    }

    func moveWindow(_ id: UUID, to workspace: Int, on screen: NSScreen) {
        removeWindow(id)
        addWindow(id, to: workspace, on: screen)
    }

    func workspace(containing windowID: UUID) -> Workspace? {
        for sid in workspaces.keys {
            for (_, ws) in workspaces[sid]! {
                if ws.windowIDs.contains(windowID) { return ws }
            }
        }
        return nil
    }

    // MARK: - Screen ID

    func screenID(_ screen: NSScreen) -> String {
        // Use the screen's unique display ID as key
        if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return "\(id)"
        }
        return screen.localizedName
    }
}
