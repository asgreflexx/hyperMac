import Carbon
import Foundation

/// A parsed key binding consisting of a Carbon key code and modifier flags.
struct KeyBinding: Equatable {
    let keyCode: UInt32
    let modifierFlags: UInt32

    /// Action identifier for this binding.
    var action: HotkeyAction

    /// Parse a human-readable string like "cmd+shift+h" into a KeyBinding.
    /// Returns nil if the string cannot be parsed.
    static func parse(_ string: String, action: HotkeyAction) -> KeyBinding? {
        let parts = string.lowercased().split(separator: "+").map(String.init)
        guard !parts.isEmpty else { return nil }

        let keyString = parts.last!
        let modStrings = parts.dropLast()

        guard let keyCode = keyCodeFor(keyString) else {
            print("[KeyBinding] Unknown key: \(keyString)")
            return nil
        }

        var modifiers: UInt32 = 0
        for mod in modStrings {
            switch mod {
            case "cmd", "command":  modifiers |= UInt32(cmdKey)
            case "shift":           modifiers |= UInt32(shiftKey)
            case "opt", "option":   modifiers |= UInt32(optionKey)
            case "ctrl", "control": modifiers |= UInt32(controlKey)
            default:
                print("[KeyBinding] Unknown modifier: \(mod)")
                return nil
            }
        }

        return KeyBinding(keyCode: keyCode, modifierFlags: modifiers, action: action)
    }

    // MARK: - Default Bindings from Config

    static func defaults(from config: Config) -> [KeyBinding] {
        let kb = config.keybindings
        let pairs: [(String, HotkeyAction)] = [
            (kb.focusLeft,  .focusLeft),
            (kb.focusDown,  .focusDown),
            (kb.focusUp,    .focusUp),
            (kb.focusRight, .focusRight),

            (kb.moveLeft,  .moveLeft),
            (kb.moveDown,  .moveDown),
            (kb.moveUp,    .moveUp),
            (kb.moveRight, .moveRight),

            (kb.toggleFloat,      .toggleFloat),
            (kb.toggleFullscreen, .toggleFullscreen),
            (kb.cycleLayout,      .cycleLayout),
            (kb.closeWindow,      .closeWindow),
            (kb.reloadConfig,     .reloadConfig),

            (kb.workspace1, .switchWorkspace(1)),
            (kb.workspace2, .switchWorkspace(2)),
            (kb.workspace3, .switchWorkspace(3)),
            (kb.workspace4, .switchWorkspace(4)),
            (kb.workspace5, .switchWorkspace(5)),

            (kb.moveToWorkspace1, .moveToWorkspace(1)),
            (kb.moveToWorkspace2, .moveToWorkspace(2)),
            (kb.moveToWorkspace3, .moveToWorkspace(3)),
            (kb.moveToWorkspace4, .moveToWorkspace(4)),
            (kb.moveToWorkspace5, .moveToWorkspace(5)),
        ]

        return pairs.compactMap { KeyBinding.parse($0.0, action: $0.1) }
    }
}

// MARK: - Actions

enum HotkeyAction: Equatable {
    case focusLeft, focusDown, focusUp, focusRight
    case moveLeft, moveDown, moveUp, moveRight
    case toggleFloat
    case toggleFullscreen
    case cycleLayout
    case closeWindow
    case reloadConfig
    case switchWorkspace(Int)
    case moveToWorkspace(Int)
}

// MARK: - Key Code Table

private func keyCodeFor(_ key: String) -> UInt32? {
    let table: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
        ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
        "tab": 48, "space": 49, "`": 50, "delete": 51, "escape": 53, "esc": 53,
        "return": 36, "enter": 36,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96,
        "f6": 97, "f7": 98, "f8": 100, "f9": 101, "f10": 109,
        "f11": 103, "f12": 111,
        "left": 123, "right": 124, "down": 125, "up": 126,
    ]
    return table[key]
}
