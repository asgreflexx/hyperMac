# hyperMac

A Hyprland-inspired tiling window manager for macOS. Lives in your menu bar, automatically tiles every window, and stays out of your way.

## Features

- **BSP layout** — Binary Space Partitioning splits the screen recursively, giving every window an equal share of space
- **Master-Stack layout** — One primary window takes a large left pane; remaining windows stack evenly on the right
- **Cycle layouts** on the fly with a single hotkey
- **5 workspaces** per display — move windows between them and switch instantly
- **Float toggle** — pull any window out of the tiling grid and back in
- **Vim-style focus & move** hotkeys (h/j/k/l)
- **TOML config** — gaps, ratios, and every keybinding are customisable
- **Menu-bar only** — no Dock icon, no window of its own

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`)
- Accessibility permission (macOS will prompt on first launch)

## Installation

### Option A — Download DMG (easiest)

1. Download the latest `hyperMac-x.x.x.dmg` from the [Releases](../../releases) page.
2. Open the DMG and drag **hyperMac.app** into your **Applications** folder.
3. Launch hyperMac from Applications.
4. macOS will block the app the first time because it is not notarised.
   Right-click (or Control-click) the app icon and choose **Open**, then confirm.
5. Grant **Accessibility** access when prompted:
   **System Settings → Privacy & Security → Accessibility → enable hyperMac**.
6. hyperMac appears in your menu bar and starts tiling immediately.

### Option B — Build from source

```bash
# 1. Clone
git clone https://github.com/yourusername/hyperMac.git
cd hyperMac

# 2. Build & run (builds release binary, signs ad-hoc, launches)
./run.sh
```

To build a distributable DMG:

```bash
./release.sh
# Produces hyperMac-0.1.0.dmg in the project root
```

## Configuration

hyperMac reads `~/.config/hypermac/config.toml` on launch. If the file does not exist, built-in defaults are used. Copy the example config to get started:

```bash
mkdir -p ~/.config/hypermac
cp config.toml ~/.config/hypermac/config.toml
```

Reload the config at any time with `Cmd+Shift+R` (no restart needed).

### Example config

```toml
[general]
gaps_inner   = 8      # gap between windows (px)
gaps_outer   = 12     # gap between windows and screen edge (px)
master_ratio = 0.55   # master pane width in Master-Stack layout (0.0–1.0)
split_ratio  = 0.5    # split ratio for BSP layout (0.0–1.0)

[layouts]
default = "bsp"       # "bsp" or "masterstack"

[keybindings]
focus_left  = "cmd+h"
focus_down  = "cmd+j"
focus_up    = "cmd+k"
focus_right = "cmd+l"

move_left   = "cmd+shift+h"
move_down   = "cmd+shift+j"
move_up     = "cmd+shift+k"
move_right  = "cmd+shift+l"

toggle_float      = "cmd+shift+space"
toggle_fullscreen = "cmd+shift+f"
cycle_layout      = "cmd+space"
close_window      = "cmd+shift+q"
reload_config     = "cmd+shift+r"

workspace_1 = "cmd+1"
workspace_2 = "cmd+2"
workspace_3 = "cmd+3"
workspace_4 = "cmd+4"
workspace_5 = "cmd+5"

move_to_workspace_1 = "cmd+shift+1"
move_to_workspace_2 = "cmd+shift+2"
move_to_workspace_3 = "cmd+shift+3"
move_to_workspace_4 = "cmd+shift+4"
move_to_workspace_5 = "cmd+shift+5"
```

Modifier keys: `cmd`, `shift`, `opt` / `option`, `ctrl` / `control`.

## Default Keybindings

### Focus

| Key | Action |
|-----|--------|
| `Cmd+H` | Focus window to the left |
| `Cmd+J` | Focus window below |
| `Cmd+K` | Focus window above |
| `Cmd+L` | Focus window to the right |

### Move

| Key | Action |
|-----|--------|
| `Cmd+Shift+H` | Swap window left |
| `Cmd+Shift+J` | Swap window down |
| `Cmd+Shift+K` | Swap window up |
| `Cmd+Shift+L` | Swap window right |

### Layout

| Key | Action |
|-----|--------|
| `Cmd+Space` | Cycle between BSP and Master-Stack |
| `Cmd+Shift+Space` | Toggle float for focused window |
| `Cmd+Shift+F` | Toggle fullscreen for focused window |

### Workspaces

| Key | Action |
|-----|--------|
| `Cmd+1` – `Cmd+5` | Switch to workspace 1–5 |
| `Cmd+Shift+1` – `Cmd+Shift+5` | Move focused window to workspace 1–5 |

### Other

| Key | Action |
|-----|--------|
| `Cmd+Shift+Q` | Close focused window |
| `Cmd+Shift+R` | Reload config |

## Layouts

### BSP (Binary Space Partitioning)

Each new window splits the available space in half. The screen is divided recursively, so every window always gets an equal share.

```
┌─────────┬─────────┐
│         │    2    │
│    1    ├────┬────┤
│         │ 3  │ 4  │
└─────────┴────┴────┘
```

### Master-Stack

The first window takes a large pane on the left (`master_ratio`). All other windows stack evenly on the right.

```
┌───────────┬────────┐
│           │   2    │
│     1     ├────────┤
│  (master) │   3    │
│           ├────────┤
│           │   4    │
└───────────┴────────┘
```

## Troubleshooting

**Windows are not being tiled**
- Confirm Accessibility permission is granted: System Settings → Privacy & Security → Accessibility.
- Some apps (e.g. system dialogs, panels) are intentionally excluded from tiling.

**A window keeps floating after toggling**
- Press `Cmd+Shift+Space` while the window is focused to return it to the tiling grid.

**Hotkeys are not working**
- Another app may be capturing the same shortcuts. Change the conflicting binding in `config.toml` and reload with `Cmd+Shift+R`.

**Config changes have no effect**
- Make sure the file is saved to `~/.config/hypermac/config.toml` and press `Cmd+Shift+R`.

## License

MIT
