import AppKit
import ApplicationServices

/// Wraps an AXUIElement window reference.
/// Provides typed access to frame, title, and window state attributes.
final class AXWindowWrapper {
    let element: AXUIElement
    let pid: pid_t

    init(element: AXUIElement, pid: pid_t) {
        self.element = element
        self.pid = pid
    }

    // MARK: - Attributes

    var title: String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
        return value as? String
    }

    var isMinimized: Bool {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value)
        return (value as? Bool) ?? false
    }

    var isFullScreen: Bool {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &value)
        return (value as? Bool) ?? false
    }

    var subrole: String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value)
        return value as? String
    }

    var isSheet: Bool {
        subrole == "AXSheet"
    }

    /// True for real, user-visible windows that should be tiled.
    ///
    /// Subrole rules:
    ///   - "AXStandardWindow" → always admit (native apps)
    ///   - nil subrole → admit if the window has a non-empty title (JVM apps like
    ///     IntelliJ IDEA report nil subrole; Terminal ghost/internal AX windows
    ///     also have nil subrole but always have an empty title)
    ///   - any other subrole (AXDialog, AXFloatingWindow, …) → reject
    var isStandardWindow: Bool {
        switch subrole {
        case kAXStandardWindowSubrole as String:
            return true
        case nil:
            return !(title ?? "").isEmpty
        default:
            return false
        }
    }

    /// Returns false for system-locked windows (e.g. Finder desktop) that cannot be repositioned.
    var isMovable: Bool {
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &settable)
        return settable.boolValue
    }

    // MARK: - Frame (NSScreen coordinates, top-left origin)

    /// Returns the window frame in NSScreen coordinates (top-left origin on primary screen).
    var frame: CGRect {
        get {
            return CGRect(origin: position, size: size)
        }
    }

    /// AXPosition is in Quartz/global coordinates (bottom-left origin, primary screen).
    private var position: CGPoint {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let axVal = value else { return .zero }
        var point = CGPoint.zero
        AXValueGetValue(axVal as! AXValue, .cgPoint, &point)
        return point
    }

    private var size: CGSize {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let axVal = value else { return .zero }
        var sz = CGSize.zero
        AXValueGetValue(axVal as! AXValue, .cgSize, &sz)
        return sz
    }

    /// Set the window frame using NSScreen (top-left) coordinates.
    /// Converts to AX Quartz coordinates internally.
    func setFrame(_ rect: CGRect) {
        // AX uses Quartz coordinates: y=0 is bottom of primary screen.
        // NSScreen coordinates: y=0 is top-left of primary screen's visible area.
        // AX origin (top-left of window) in Quartz = (rect.x, primaryScreenHeight - rect.y - rect.height)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0

        var axOrigin = CGPoint(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height
        )
        var axSize = CGSize(width: rect.width, height: rect.height)

        // Set size before position: if position were set first with the old (larger) size,
        // macOS may clamp the window to avoid going off-screen, leaving it at the wrong
        // position after the size is applied — the primary cause of gaps on layout switch.
        if let sizeValue = AXValueCreate(.cgSize, &axSize) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        }
        if let posValue = AXValueCreate(.cgPoint, &axOrigin) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)
        }
    }

    /// Disable enhanced user interface (reduces animation lag during tiling).
    func disableEnhancedUI() {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, false as CFTypeRef)
    }
}

// MARK: - Equatable

extension AXWindowWrapper: Equatable {
    static func == (lhs: AXWindowWrapper, rhs: AXWindowWrapper) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }
}
