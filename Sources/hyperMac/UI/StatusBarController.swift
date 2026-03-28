import AppKit

/// Manages the macOS menu bar status item for hyperMac.
final class StatusBarController {
    private var statusItem: NSStatusItem!
    private weak var delegate: StatusBarDelegate?

    init(delegate: StatusBarDelegate? = nil) {
        self.delegate = delegate
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "hyperMac")
            button.image?.isTemplate = true
        }

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "hyperMac", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(.separator())

        let layoutItem = NSMenuItem(title: layoutTitle(), action: #selector(cycleLayout), keyEquivalent: "")
        layoutItem.target = self
        menu.addItem(layoutItem)

        let toggleItem = NSMenuItem(title: enabledTitle(), action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let reloadItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit hyperMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    func updateMenu() {
        statusItem.menu = buildMenu()
    }

    private func layoutTitle() -> String {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let name = LayoutEngine.shared.getActiveLayoutName(for: screen)
        let display = name == "bsp" ? "BSP" : "MasterStack"
        return "Layout: \(display) (Cycle)"
    }

    private func enabledTitle() -> String {
        WindowManager.shared.isEnabled ? "Disable Tiling" : "Enable Tiling"
    }

    @objc private func cycleLayout() {
        guard let screen = NSScreen.main else { return }
        WindowManager.shared.cycleLayout(screen: screen)
        updateMenu()
    }

    @objc private func toggleEnabled() {
        let wm = WindowManager.shared
        wm.setEnabled(!wm.isEnabled)
        updateMenu()
    }

    @objc private func reloadConfig() {
        WindowManager.shared.reloadConfig()
    }
}

protocol StatusBarDelegate: AnyObject {}
