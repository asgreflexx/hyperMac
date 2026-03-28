import AppKit

// hyperMac runs as a menu-bar-only application.
// LSUIElement is set programmatically: no Dock icon, no main window.

let app = NSApplication.shared
// Hide from Dock and App Switcher — equivalent to LSUIElement = YES
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
