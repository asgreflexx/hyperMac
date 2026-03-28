import Carbon
import AppKit

/// Manages global hotkey registration via the Carbon RegisterEventHotKey API.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var registeredHotkeys: [(ref: EventHotKeyRef, id: UInt32)] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    // MARK: - Setup

    func setup(bindings: [KeyBinding]) {
        unregisterAll()
        installEventHandler()
        for binding in bindings {
            register(binding)
        }
    }

    // MARK: - Registration

    private func register(_ binding: KeyBinding) {
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: fourCharCode("hMac"), id: id)
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.modifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            print("[HotkeyManager] Failed to register hotkey for action \(binding.action): \(status)")
            return
        }

        registeredHotkeys.append((ref: ref, id: id))
        handlers[id] = { [weak self] in
            self?.dispatch(binding.action)
        }
    }

    private func unregisterAll() {
        for entry in registeredHotkeys {
            UnregisterEventHotKey(entry.ref)
        }
        registeredHotkeys.removeAll()
        handlers.removeAll()

        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    // MARK: - Event Handler

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // InstallApplicationEventHandler is a C macro; use InstallEventHandler with GetApplicationEventTarget()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                manager.handlers[hotKeyID.id]?()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
    }

    // MARK: - Action Dispatch

    private func dispatch(_ action: HotkeyAction) {
        let wm = WindowManager.shared
        switch action {
        case .focusLeft:  wm.moveFocus(direction: .left)
        case .focusDown:  wm.moveFocus(direction: .down)
        case .focusUp:    wm.moveFocus(direction: .up)
        case .focusRight: wm.moveFocus(direction: .right)

        case .moveLeft:  wm.moveWindow(direction: .left)
        case .moveDown:  wm.moveWindow(direction: .down)
        case .moveUp:    wm.moveWindow(direction: .up)
        case .moveRight: wm.moveWindow(direction: .right)

        case .toggleFloat:
            if let id = wm.focusedWindowID { wm.toggleFloat(windowID: id) }

        case .toggleFullscreen:
            if let id = wm.focusedWindowID { wm.toggleFullscreen(windowID: id) }

        case .cycleLayout:
            if let screen = NSScreen.main { wm.cycleLayout(screen: screen) }

        case .closeWindow:
            if let id = wm.focusedWindowID { wm.closeWindow(windowID: id) }

        case .reloadConfig:
            wm.reloadConfig()

        case .switchWorkspace(let n):
            wm.switchWorkspace(n)

        case .moveToWorkspace(let n):
            if let id = wm.focusedWindowID { wm.moveToWorkspace(windowID: id, workspace: n) }
        }
    }
}

// MARK: - Helpers

private func fourCharCode(_ string: String) -> OSType {
    let chars = string.utf8.prefix(4)
    var result: OSType = 0
    for char in chars {
        result = (result << 8) | OSType(char)
    }
    return result
}
