import AppKit
import ApplicationServices

/// Manages Accessibility and Screen Recording permissions.
final class PermissionManager {

    /// Check if Accessibility API access is granted.
    /// If not, prompt the user via the system dialog.
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            print("[PermissionManager] Accessibility permission not granted.")
            showPermissionAlert()
        }
        return trusted
    }

    /// Returns whether AX is currently trusted (no prompt).
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    /// Poll until permission is granted, then call completion on main queue.
    static func waitForPermission(completion: @escaping () -> Void) {
        if isAccessibilityGranted {
            completion()
            return
        }
        DispatchQueue.global(qos: .background).async {
            while !isAccessibilityGranted {
                Thread.sleep(forTimeInterval: 1.0)
            }
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    private static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            hyperMac needs Accessibility access to manage window positions.

            Please go to System Settings → Privacy & Security → Accessibility \
            and enable hyperMac.
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        } else {
            NSApp.terminate(nil)
        }
    }
}
