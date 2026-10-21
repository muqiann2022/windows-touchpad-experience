# Windows Touchpad Experience

**Windows-style touchpad gestures for Linux: an Omarchy / Hyprland window
switcher built with Quickshell on Wayland.**

Bring a familiar Windows-like precision touchpad workflow to your Linux desktop:
three-finger swipe window switching across workspaces with thumbnail previews, swipe up to
fullscreen, swipe down to restore or stash, four-finger up/down scratchpad access, and optional four-finger virtual
desktop switching. The goal is a similar interaction experience, rather than
an exact implementation of every Windows gesture.

Slide three fingers horizontally to open a spatial window overview, continue
moving to highlight a window, then lift to focus it. No pointer or click is
required. Window thumbnails keep the desktop's original layout, including
off-screen windows in Hyprland's scrolling layout.

**中文：** 为 Linux Wayland 桌面实现类似 Windows 的触摸板体验，适用于
Omarchy 和 Hyprland。支持三指滑动切换窗口、窗口缩略图总览、上滑全屏、
下滑恢复或收进暂存区、四指上下滑打开和关闭暂存区，以及跨虚拟桌面选择窗口。

Experimental **v0.1.0** · [MIT license](LICENSE)

## Touchpad gestures and window switching

| Gesture | Action |
| --- | --- |
| Three fingers, horizontal | Open the overview, select by movement, lift to switch |
| Three fingers, up | Fullscreen the active window; repeating keeps it fullscreen |
| Three fingers, down while fullscreen | Restore the window |
| Three fingers, down otherwise | Move the active window to `special:scratchpad` |
| Four fingers, up | Open `special:scratchpad`; repeating keeps it open |
| Four fingers, down | Close the scratchpad and return to the underlying desktop |
| Escape | Cancel the overview |

The overview preserves window positions, sizes, and spacing, including windows
outside a scrolling layout's viewport. The overview uses about 52% of a landscape
screen's height, increasing smoothly to 70% on tall portrait screens. Preview
scale also respects the available width so vertically split windows remain
readable. Workspaces on the focused monitor appear side by side in numeric
order, with workspace labels. Swipe in either direction from the active window
to select across workspaces; lifting focuses the selected window on its desktop.
Wide layouts scroll horizontally and keep the selected window visible.
Selection borders are square and follow the current Omarchy theme accent.

On Omarchy, **Super+S** shows/hides the scratchpad. To return a scratchpad window
to a normal workspace, focus it and press **Super+Shift+1…9** for that workspace.

## Requirements

Tested with **Omarchy 4.0.6**, **Hyprland 0.56.2**, and **Quickshell 0.3.2**.
This plugin requires Omarchy's Quickshell shell and Hyprland's Lua gesture API;
it is not a standalone app. Other versions are unverified.

The plugin takes over three-finger horizontal/up/down gestures. Remove
conflicting three-finger bindings from your Hyprland configuration before
enabling it, including generic `vertical` or `swipe` bindings. Existing custom
bindings are not saved or restored by the plugin. Also remove conflicting
four-finger up/down or generic vertical/swipe bindings; four-finger horizontal
workspace switching remains independent.

## Install on Omarchy / Hyprland

Install directly from GitHub:

```bash
omarchy plugin add https://github.com/muqiann2022/windows-touchpad-experience.git --enable
omarchy restart shell
```

Or clone the repository and install locally:

```bash
git clone https://github.com/muqiann2022/windows-touchpad-experience.git
cd windows-touchpad-experience
```

From this repository's root:

```bash
omarchy plugin validate .
mkdir -p ~/.config/omarchy/plugins/muqiann.window-glide
cp -r app shell manifest.json README.md LICENSE ~/.config/omarchy/plugins/muqiann.window-glide/
omarchy plugin enable muqiann.window-glide
omarchy restart shell
```

Restart the shell after installing or updating code, since
Omarchy can retain an already loaded service during a plugin rescan.

To disable and restore the gestures in your Hyprland configuration:

```bash
omarchy plugin disable muqiann.window-glide
omarchy restart shell
hyprctl reload
hyprctl configerrors
```

The reload matters: gesture callbacks registered inside Hyprland outlive the
plugin process until Hyprland's configuration is reloaded. Disabling does not
move windows out of the scratchpad.

## Four-finger gestures for virtual desktop / workspace switching

This uses Hyprland directly and is independent of the plugin. Add to
`~/.config/hypr/input.lua`, avoiding duplicate bindings:

```lua
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.config({ gestures = { workspace_swipe_distance = 150 } })
```

Apply with `hyprctl reload` and check `hyprctl configerrors`.
See the [Hyprland gesture documentation](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/).

## Current limits

- The overview includes regular workspaces on the focused monitor.
  Multi-monitor transitions and special-workspace overviews are not supported.
- Previews use Hyprland's individual-window export, including windows on inactive
  workspaces and outside a scrolling layout's viewport. If the compositor cannot
  supply a usable frame, the overview retains its last usable preview in memory
  or displays the window title while waiting.
- Previews refresh at approximately five frames per second while the overview is
  open. Effectively black or transparent frames are rejected, so an intentionally
  black window can retain its previous preview or display its title. Nothing is
  saved to disk; restarting the shell clears the cache.
- Closing a window or changing workspace/monitor cancels an open overview.
- Fullscreen restore and scratchpad placement use Hyprland's own layout rules.

## Development

Requires Node.js and Lua for the dependency-free tests:

```bash
npm test
omarchy plugin validate .
```

With Qt 6 development tools installed, run the title-rendering regression test:

```bash
QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion /usr/lib/qt6/bin/qmltestrunner -input tests/tst_overlay.qml
```

`app/gesture.lua` registers gestures; `shell/Service.qml` handles snapshots and
focus; `shell/Overlay.qml` draws and captures previews; `app/selection.js`
contains layout and selection helpers.

## License

[MIT](LICENSE).
