import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Check / request Accessibility permission
        let hasPermission = PermissionManager.checkAccessibilityPermission()

        // 2. Setup menu bar
        statusBarController = StatusBarController()
        statusBarController.setup()

        // 3. Load configuration
        ConfigLoader.installDefaultIfNeeded()
        let config = ConfigLoader.load()

        // 4. Initialize WindowManager with config
        WindowManager.shared.setup(config: config)

        // 5. Register hotkeys
        let bindings = KeyBinding.defaults(from: config)
        HotkeyManager.shared.setup(bindings: bindings)

        if !hasPermission {
            // Wait for permission then restart observation
            PermissionManager.waitForPermission {
                WindowManager.shared.setup(config: config)
                HotkeyManager.shared.setup(bindings: bindings)
                print("[AppDelegate] Accessibility permission granted — observation started.")
            }
        }

        print("[AppDelegate] hyperMac launched.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("[AppDelegate] hyperMac terminating.")
    }
}
