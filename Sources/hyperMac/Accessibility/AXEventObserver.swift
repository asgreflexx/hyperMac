import AppKit
import ApplicationServices

/// Observes AX notifications for a single application process.
/// Notifies `WindowManager` of window lifecycle events.
final class AXEventObserver {
    let pid: pid_t
    private var observer: AXObserver?
    private let appElement: AXUIElement

    init(pid: pid_t) {
        self.pid = pid
        self.appElement = AXUIElementCreateApplication(pid)
    }

    deinit {
        stop()
    }

    func start() {
        var obs: AXObserver?
        let result = AXObserverCreate(pid, eventCallback, &obs)
        guard result == .success, let obs = obs else {
            print("[AXEventObserver] Failed to create observer for pid \(pid): \(result.rawValue)")
            return
        }
        self.observer = obs

        let notifications = [
            kAXWindowCreatedNotification,
            kAXUIElementDestroyedNotification,
            kAXWindowMovedNotification,
            kAXWindowResizedNotification,
            kAXFocusedWindowChangedNotification,
            kAXApplicationActivatedNotification,
        ]

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        for notification in notifications {
            AXObserverAddNotification(obs, appElement, notification as CFString, selfPtr)
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(obs),
            .defaultMode
        )

        // Immediately enumerate existing windows for this app
        enumerateExistingWindows()
    }

    func stop() {
        guard let obs = observer else { return }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(obs),
            .defaultMode
        )
        observer = nil
    }

    private func enumerateExistingWindows() {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return }

        for winElement in windows {
            let wrapper = AXWindowWrapper(element: winElement, pid: pid)
            guard !wrapper.isMinimized, !wrapper.isSheet, !wrapper.isFullScreen,
                  wrapper.isMovable, wrapper.isStandardWindow else { continue }
            WindowManager.shared.addWindow(wrapper)
        }
    }
}

// MARK: - C Callback

private func eventCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ userData: UnsafeMutableRawPointer?
) {
    guard let userData = userData else { return }
    let obs = Unmanaged<AXEventObserver>.fromOpaque(userData).takeUnretainedValue()

    let notif = notification as String
    let wrapper = AXWindowWrapper(element: element, pid: obs.pid)

    DispatchQueue.main.async {
        switch notif {
        case kAXWindowCreatedNotification:
            guard !wrapper.isSheet, !wrapper.isMinimized, !wrapper.isFullScreen,
                  wrapper.isMovable, wrapper.isStandardWindow else { return }
            WindowManager.shared.addWindow(wrapper)

        case kAXUIElementDestroyedNotification:
            WindowManager.shared.removeWindow(pid: obs.pid, axElement: element)

        case kAXWindowMovedNotification:
            // User dragged a window — mark it floating
            WindowManager.shared.handleWindowMoved(wrapper)

        case kAXWindowResizedNotification:
            WindowManager.shared.handleWindowResized(wrapper)

        case kAXFocusedWindowChangedNotification:
            WindowManager.shared.handleFocusChanged(wrapper)

        case kAXApplicationActivatedNotification:
            // Re-sync focused window
            var focused: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                AXUIElementCreateApplication(obs.pid),
                kAXFocusedWindowAttribute as CFString,
                &focused
            ) == .success, let focusedEl = focused {
                let fw = AXWindowWrapper(element: focusedEl as! AXUIElement, pid: obs.pid)
                WindowManager.shared.handleFocusChanged(fw)
            }

        default:
            break
        }
    }
}
