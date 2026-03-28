import Foundation
import AppKit

/// Top-level configuration loaded from ~/.config/hypermac/config.toml
struct Config {
    struct General {
        var gapsInner: CGFloat = 8
        var gapsOuter: CGFloat = 12
        var borderWidth: CGFloat = 2
        var masterRatio: CGFloat = 0.55
        var splitRatio: CGFloat = 0.5
    }

    struct Layouts {
        var defaultLayout: String = "bsp"
    }

    struct KeyBindings {
        var focusLeft: String = "cmd+h"
        var focusDown: String = "cmd+j"
        var focusUp: String = "cmd+k"
        var focusRight: String = "cmd+l"

        var moveLeft: String = "cmd+shift+h"
        var moveDown: String = "cmd+shift+j"
        var moveUp: String = "cmd+shift+k"
        var moveRight: String = "cmd+shift+l"

        var toggleFloat: String = "cmd+shift+space"
        var toggleFullscreen: String = "cmd+shift+f"
        var cycleLayout: String = "cmd+space"
        var closeWindow: String = "cmd+shift+q"
        var reloadConfig: String = "cmd+shift+r"

        var resizeMasterGrow: String   = "cmd+="
        var resizeMasterShrink: String = "cmd+-"

        var workspace1: String = "cmd+1"
        var workspace2: String = "cmd+2"
        var workspace3: String = "cmd+3"
        var workspace4: String = "cmd+4"
        var workspace5: String = "cmd+5"

        var moveToWorkspace1: String = "cmd+shift+1"
        var moveToWorkspace2: String = "cmd+shift+2"
        var moveToWorkspace3: String = "cmd+shift+3"
        var moveToWorkspace4: String = "cmd+shift+4"
        var moveToWorkspace5: String = "cmd+shift+5"
    }

    var general = General()
    var layouts = Layouts()
    var keybindings = KeyBindings()

    static let `default` = Config()
}
