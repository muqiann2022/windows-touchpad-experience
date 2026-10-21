# Repository Guidelines

## Project Structure & Module Organization

This repository is an Omarchy / Hyprland plugin using Quickshell on Wayland.
- `app/gesture.lua` registers three-finger gestures and dispatches events.
- `app/selection.js` provides shared layout, selection, and preview helpers.
- `shell/Service.qml` manages window snapshots, gesture state, and focus.
- `shell/Overlay.qml` renders the overview and captures window previews.
- `manifest.json` declares plugin metadata and QML entry points.
- `tests/` contains JavaScript, Lua, and QML regression tests. There is no separate asset directory; previews are captured at runtime.

## Build, Test, and Development Commands

Run commands from the repository root. No compilation or dependency installation is currently required.

- `npm test`: runs dependency-free Node.js assertion tests and Lua gesture tests; requires Node.js and Lua.
- `omarchy plugin validate .`: validates the plugin structure and manifest.
- Run the Qt Quick title-rendering regression with Qt 6 development tools:

```bash
QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion /usr/lib/qt6/bin/qmltestrunner -input tests/tst_overlay.qml
```

Follow `README.md` for local installation. After copying updated plugin files, run `omarchy restart shell` to reload the service.

## Coding Style & Naming Conventions

Use two-space indentation across JavaScript, Lua, and QML. Follow nearby syntax: JavaScript helpers use semicolons and `var`; QML JavaScript generally uses `const`/`let` without semicolons. Use camelCase for functions and properties, PascalCase for QML component filenames, and descriptive assertion messages. Preserve `.pragma library` in `app/selection.js`. No formatter or linter is configured.

## Testing Guidelines

Add regression coverage for behavior changes. JavaScript tests use `node:assert/strict` and VM contexts; Lua tests mock Hyprland; QML tests use QtTest. Name tests `tests/*.test.js`, `tests/*.test.lua`, or `tests/tst_*.qml`. Add new JavaScript/Lua test files to the `npm test` script. No coverage threshold is configured. Manually check gesture and preview changes in the supported desktop environment.

## Commit & Pull Request Guidelines

Existing history uses concise imperative subjects, such as `Fix window title rendering to use plain text`; no mandatory prefix convention is established. Keep commits focused. PRs should explain behavior changes, list validation performed, link relevant issues, and include screenshots or recordings for overview changes. Report desktop versions for integration changes. Treat window titles as untrusted text and preserve `Text.PlainText` rendering.
