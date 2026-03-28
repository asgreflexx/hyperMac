import AppKit
import ApplicationServices

// MARK: - ManagedWindow Model

/// Represents a single managed window tracked by hyperMac.
struct ManagedWindow: Identifiable {
    let id: UUID
    let axWrapper: AXWindowWrapper
    var isFloating: Bool
    var lastTiledFrame: CGRect?
    var workspaceID: Int
    var orderIndex: Int  // Insertion order for layout ordering
    var addedAt: Date    // When this window was registered; used to suppress spurious move events
}

// MARK: - WindowManager

/// Central coordinator. Maintains the window list, drives tiling, and handles all commands.
final class WindowManager {
    static let shared = WindowManager()

    // MARK: State
    var windows: [UUID: ManagedWindow] = [:]
    var focusedWindowID: UUID?
    var isEnabled: Bool = true

    private var config: Config = .default
    private var appObservers: [pid_t: AXEventObserver] = [:]
    private var orderCounter: Int = 0

    // Debounce retile to avoid hammering AX API during rapid events
    private var retileWorkItem: DispatchWorkItem?

    // Suppress move→float conversion while we are applying tiled frames
    private var suppressMoveUntil: Date = .distantPast

    private init() {}

    // MARK: - Setup

    func setup(config: Config) {
        self.config = config

        // Update layout parameters from config
        LayoutEngine.shared.bspLayout.splitRatio = config.general.splitRatio
        LayoutEngine.shared.masterStackLayout.masterRatio = config.general.masterRatio

        // Setup workspaces for all screens
        WorkspaceManager.shared.setup(
            screens: NSScreen.screens,
            defaultLayout: config.layouts.defaultLayout
        )

        // Set default layout per screen
        for screen in NSScreen.screens {
            LayoutEngine.shared.setLayout(config.layouts.defaultLayout, for: screen)
        }

        // Observe all running apps
        observeRunningApplications()

        // Observe new apps launching/quitting
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    // MARK: - App Observation

    private func observeRunningApplications() {
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            startObserving(app: app)
        }
    }

    private func startObserving(app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid > 0, appObservers[pid] == nil else { return }
        let observer = AXEventObserver(pid: pid)
        appObservers[pid] = observer
        observer.start()
    }

    private func stopObserving(pid: pid_t) {
        appObservers[pid]?.stop()
        appObservers.removeValue(forKey: pid)
    }

    @objc private func appLaunched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.activationPolicy == .regular else { return }
        startObserving(app: app)
    }

    @objc private func appTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        stopObserving(pid: app.processIdentifier)
    }

    // MARK: - Window Lifecycle

    func addWindow(_ wrapper: AXWindowWrapper) {
        // Avoid duplicates
        guard !windows.values.contains(where: { CFEqual($0.axWrapper.element, wrapper.element) }) else { return }

        wrapper.disableEnhancedUI()

        let screen = screenForWindow(wrapper) ?? NSScreen.main ?? NSScreen.screens[0]
        let activeWS = WorkspaceManager.shared.activeWorkspace(for: screen)?.id ?? 1

        let managed = ManagedWindow(
            id: UUID(),
            axWrapper: wrapper,
            isFloating: false,
            lastTiledFrame: nil,
            workspaceID: activeWS,
            orderIndex: orderCounter,
            addedAt: Date()
        )
        orderCounter += 1
        windows[managed.id] = managed
        WorkspaceManager.shared.addWindow(managed.id, to: activeWS, on: screen)

        print("[WindowManager] Added window: \(wrapper.title ?? "(untitled)") pid=\(wrapper.pid)")
        scheduleRetile(screen: screen)
    }

    func removeWindow(pid: pid_t, axElement: AXUIElement) {
        guard let entry = windows.first(where: {
            $0.value.axWrapper.pid == pid && CFEqual($0.value.axWrapper.element, axElement)
        }) else { return }

        let id = entry.key
        let screen = screenForWindow(entry.value.axWrapper)
        WorkspaceManager.shared.removeWindow(id)
        windows.removeValue(forKey: id)

        if focusedWindowID == id { focusedWindowID = nil }

        print("[WindowManager] Removed window pid=\(pid)")
        if let screen = screen {
            scheduleRetile(screen: screen)
        } else {
            retileAll()
        }
    }

    func handleWindowMoved(_ wrapper: AXWindowWrapper) {
        guard let id = findWindowID(for: wrapper) else { return }
        if var window = windows[id], !window.isFloating {
            let now = Date()
            // Ignore moves fired by the OS when a window is first created (grace period)
            let isNewWindow = now.timeIntervalSince(window.addedAt) < 1.0
            // Ignore moves caused by our own setFrame calls during tiling
            let isTilingMove = now < suppressMoveUntil
            guard !isNewWindow && !isTilingMove else { return }

            window.isFloating = true
            windows[id] = window
            print("[WindowManager] Window dragged → marked floating: \(wrapper.title ?? "")")
            if let screen = screenForWindow(wrapper) {
                scheduleRetile(screen: screen)
            }
        }
    }

    func handleWindowResized(_ wrapper: AXWindowWrapper) {
        guard let id = findWindowID(for: wrapper) else { return }
        if let window = windows[id], !window.isFloating {
            // User manually resized a tiled window — retile to enforce layout
            if let screen = screenForWindow(wrapper) {
                scheduleRetile(screen: screen)
            }
        }
    }

    func handleFocusChanged(_ wrapper: AXWindowWrapper) {
        if let id = findWindowID(for: wrapper) {
            focusedWindowID = id
        }
    }

    // MARK: - Retile

    func retile(screen: NSScreen) {
        guard isEnabled else { return }

        let tiledWindows = tiledWindowsOn(screen: screen)
        let gaps = NSEdgeInsets(
            top: config.general.gapsOuter,
            left: config.general.gapsOuter,
            bottom: config.general.gapsOuter,
            right: config.general.gapsOuter
        )
        let frames = LayoutEngine.shared.calculate(
            windows: tiledWindows,
            screen: screen,
            gaps: gaps,
            windowGap: config.general.gapsInner
        )
        // Suppress move→float for any AX notifications that arrive after setFrame calls
        suppressMoveUntil = Date().addingTimeInterval(0.5)
        LayoutEngine.shared.apply(frames: frames, to: tiledWindows)
    }

    func retileAll() {
        for screen in NSScreen.screens {
            retile(screen: screen)
        }
    }

    /// Debounced retile — avoids excessive AX calls during rapid events.
    private func scheduleRetile(screen: NSScreen) {
        retileWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.retile(screen: screen)
        }
        retileWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
    }

    // MARK: - Float Toggle

    func toggleFloat(windowID: UUID) {
        guard var window = windows[windowID] else { return }
        if window.isFloating {
            window.isFloating = false
            windows[windowID] = window
            print("[WindowManager] Window re-tiled: \(window.axWrapper.title ?? "")")
        } else {
            window.lastTiledFrame = window.axWrapper.frame
            window.isFloating = true
            windows[windowID] = window
            print("[WindowManager] Window floated: \(window.axWrapper.title ?? "")")
        }
        if let screen = screenForWindow(window.axWrapper) {
            retile(screen: screen)
        }
    }

    // MARK: - Fullscreen Toggle

    func toggleFullscreen(windowID: UUID) {
        guard let window = windows[windowID] else { return }
        let element = window.axWrapper.element
        var current: CFTypeRef?
        AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &current)
        let isFS = (current as? Bool) ?? false
        AXUIElementSetAttributeValue(element, "AXFullScreen" as CFString, (!isFS) as CFTypeRef)
    }

    // MARK: - Focus Movement

    func moveFocus(direction: Direction) {
        guard let focusedID = focusedWindowID,
              let screen = screenForFocused() else { return }

        let tiled = tiledWindowsOn(screen: screen)
        guard let currentIndex = tiled.firstIndex(where: { $0.id == focusedID }) else { return }

        let nextIndex: Int
        switch direction {
        case .left, .up:
            nextIndex = currentIndex > 0 ? currentIndex - 1 : tiled.count - 1
        case .right, .down:
            nextIndex = currentIndex < tiled.count - 1 ? currentIndex + 1 : 0
        }

        guard nextIndex != currentIndex else { return }
        let target = tiled[nextIndex]
        focusWindow(target.axWrapper)
        focusedWindowID = target.id
    }

    private func focusWindow(_ wrapper: AXWindowWrapper) {
        AXUIElementSetAttributeValue(wrapper.element, kAXMainAttribute as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(wrapper.element, kAXFocusedAttribute as CFString, true as CFTypeRef)
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "")
        let app = apps.first(where: { $0.processIdentifier == wrapper.pid })
            ?? NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == wrapper.pid })
        app?.activate(options: .activateIgnoringOtherApps)
    }

    // MARK: - Window Movement (BSP swap)

    func moveWindow(direction: Direction) {
        guard let focusedID = focusedWindowID,
              let screen = screenForFocused() else { return }

        let tiled = tiledWindowsOn(screen: screen)
        guard let currentIndex = tiled.firstIndex(where: { $0.id == focusedID }),
              tiled.count > 1 else { return }

        let swapIndex: Int
        switch direction {
        case .left, .up:
            swapIndex = currentIndex > 0 ? currentIndex - 1 : tiled.count - 1
        case .right, .down:
            swapIndex = currentIndex < tiled.count - 1 ? currentIndex + 1 : 0
        }

        guard swapIndex != currentIndex else { return }

        // Swap orderIndex between the two windows
        let aID = tiled[currentIndex].id
        let bID = tiled[swapIndex].id
        let aOrder = windows[aID]!.orderIndex
        let bOrder = windows[bID]!.orderIndex
        windows[aID]?.orderIndex = bOrder
        windows[bID]?.orderIndex = aOrder

        retile(screen: screen)
    }

    // MARK: - Layout Cycling

    func cycleLayout(screen: NSScreen) {
        LayoutEngine.shared.cycleLayout(for: screen)
        retile(screen: screen)
    }

    // MARK: - Window Close

    func closeWindow(windowID: UUID) {
        guard let window = windows[windowID] else { return }
        var closeButton: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            window.axWrapper.element,
            kAXCloseButtonAttribute as CFString,
            &closeButton
        ) == .success, let btn = closeButton {
            AXUIElementPerformAction(btn as! AXUIElement, kAXPressAction as CFString)
        }
    }

    // MARK: - Config Reload

    func reloadConfig() {
        let newConfig = ConfigLoader.load()
        self.config = newConfig

        // Update layout parameters
        LayoutEngine.shared.bspLayout.splitRatio = newConfig.general.splitRatio
        LayoutEngine.shared.masterStackLayout.masterRatio = newConfig.general.masterRatio

        // Re-register hotkeys
        let bindings = KeyBinding.defaults(from: newConfig)
        HotkeyManager.shared.setup(bindings: bindings)

        retileAll()
        print("[WindowManager] Config reloaded.")
    }

    // MARK: - Workspace Management

    func switchWorkspace(_ number: Int) {
        guard let screen = NSScreen.main else { return }
        let currentWS = WorkspaceManager.shared.activeWorkspace(for: screen)?.id ?? 1
        guard number != currentWS else { return }

        // Move windows on current workspace off-screen
        let currentWindows = tiledWindowsOn(screen: screen)
        for window in currentWindows {
            var offscreen = window.axWrapper.frame
            offscreen.origin.x = screen.frame.maxX + 100
            window.axWrapper.setFrame(offscreen)
        }

        WorkspaceManager.shared.switchWorkspace(number, on: screen)

        // Show windows on new workspace
        retile(screen: screen)
        print("[WindowManager] Switched to workspace \(number)")
    }

    func moveToWorkspace(windowID: UUID, workspace: Int) {
        guard var window = windows[windowID],
              let screen = screenForWindow(window.axWrapper) else { return }
        WorkspaceManager.shared.moveWindow(windowID, to: workspace, on: screen)
        window.workspaceID = workspace
        windows[windowID] = window
        retile(screen: screen)
    }

    // MARK: - Enable/Disable

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled { retileAll() }
        print("[WindowManager] \(enabled ? "Enabled" : "Disabled")")
    }

    // MARK: - Helpers

    func tiledWindowsOn(screen: NSScreen) -> [ManagedWindow] {
        let activeWS = WorkspaceManager.shared.activeWorkspace(for: screen)?.id ?? 1
        return windows.values
            .filter {
                !$0.isFloating
                && $0.workspaceID == activeWS
                && !$0.axWrapper.isMinimized
                && !$0.axWrapper.isFullScreen
            }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    func findWindowID(for wrapper: AXWindowWrapper) -> UUID? {
        windows.first(where: { CFEqual($0.value.axWrapper.element, wrapper.element) })?.key
    }

    func screenForWindow(_ wrapper: AXWindowWrapper) -> NSScreen? {
        let frame = wrapper.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main
    }

    private func screenForFocused() -> NSScreen? {
        guard let id = focusedWindowID, let w = windows[id] else { return nil }
        return screenForWindow(w.axWrapper)
    }
}
