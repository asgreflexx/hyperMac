import Foundation
import TOMLKit

/// Loads configuration from ~/.config/hypermac/config.toml
final class ConfigLoader {
    static let configPath: URL = {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".config/hypermac/config.toml")
    }()

    /// Load config from disk, returning defaults for any missing keys.
    static func load() -> Config {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            print("[ConfigLoader] No config file found at \(configPath.path), using defaults.")
            return .default
        }

        do {
            let contents = try String(contentsOf: configPath, encoding: .utf8)
            let table = try TOMLKit.TOMLTable(string: contents)
            return parse(table: table)
        } catch {
            print("[ConfigLoader] Failed to load config: \(error). Using defaults.")
            return .default
        }
    }

    /// Write the bundled default config.toml to ~/.config/hypermac/config.toml if it doesn't exist.
    static func installDefaultIfNeeded() {
        let dir = configPath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        guard !FileManager.default.fileExists(atPath: configPath.path) else { return }

        // Try to copy bundled default config
        if let bundleURL = Bundle.main.url(forResource: "config", withExtension: "toml") {
            try? FileManager.default.copyItem(at: bundleURL, to: configPath)
            print("[ConfigLoader] Installed default config at \(configPath.path)")
        }
    }

    private static func parse(table: TOMLTable) -> Config {
        var config = Config()

        if let general = table["general"]?.table {
            if let v = general["gaps_inner"]?.double { config.general.gapsInner = CGFloat(v) }
            if let v = general["gaps_outer"]?.double { config.general.gapsOuter = CGFloat(v) }
            if let v = general["border_width"]?.double { config.general.borderWidth = CGFloat(v) }
            if let v = general["master_ratio"]?.double { config.general.masterRatio = CGFloat(v) }
            if let v = general["split_ratio"]?.double { config.general.splitRatio = CGFloat(v) }
        }

        if let layouts = table["layouts"]?.table {
            if let v = layouts["default"]?.string { config.layouts.defaultLayout = v }
        }

        if let kb = table["keybindings"]?.table {
            if let v = kb["focus_left"]?.string { config.keybindings.focusLeft = v }
            if let v = kb["focus_down"]?.string { config.keybindings.focusDown = v }
            if let v = kb["focus_up"]?.string { config.keybindings.focusUp = v }
            if let v = kb["focus_right"]?.string { config.keybindings.focusRight = v }

            if let v = kb["move_left"]?.string { config.keybindings.moveLeft = v }
            if let v = kb["move_down"]?.string { config.keybindings.moveDown = v }
            if let v = kb["move_up"]?.string { config.keybindings.moveUp = v }
            if let v = kb["move_right"]?.string { config.keybindings.moveRight = v }

            if let v = kb["toggle_float"]?.string { config.keybindings.toggleFloat = v }
            if let v = kb["toggle_fullscreen"]?.string { config.keybindings.toggleFullscreen = v }
            if let v = kb["cycle_layout"]?.string { config.keybindings.cycleLayout = v }
            if let v = kb["close_window"]?.string { config.keybindings.closeWindow = v }
            if let v = kb["reload_config"]?.string { config.keybindings.reloadConfig = v }

            if let v = kb["resize_master_grow"]?.string   { config.keybindings.resizeMasterGrow = v }
            if let v = kb["resize_master_shrink"]?.string { config.keybindings.resizeMasterShrink = v }

            if let v = kb["workspace_1"]?.string { config.keybindings.workspace1 = v }
            if let v = kb["workspace_2"]?.string { config.keybindings.workspace2 = v }
            if let v = kb["workspace_3"]?.string { config.keybindings.workspace3 = v }
            if let v = kb["workspace_4"]?.string { config.keybindings.workspace4 = v }
            if let v = kb["workspace_5"]?.string { config.keybindings.workspace5 = v }

            if let v = kb["move_to_workspace_1"]?.string { config.keybindings.moveToWorkspace1 = v }
            if let v = kb["move_to_workspace_2"]?.string { config.keybindings.moveToWorkspace2 = v }
            if let v = kb["move_to_workspace_3"]?.string { config.keybindings.moveToWorkspace3 = v }
            if let v = kb["move_to_workspace_4"]?.string { config.keybindings.moveToWorkspace4 = v }
            if let v = kb["move_to_workspace_5"]?.string { config.keybindings.moveToWorkspace5 = v }
        }

        return config
    }
}
