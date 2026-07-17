# Porchlight macOS

The macOS app is a native AppKit/SwiftUI shell over the Rust CLI.

## Project

```text
apps/macos/
  Porchlight.xcodeproj
  Porchlight/
    AppDelegate.swift
    StatusBarController.swift
    SettingsWindowController.swift
    Models/
    Services/
    ViewModels/
    Views/
```

This is an Xcode project, not a SwiftPM app.

## Build

```bash
DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer" xcodebuild -project "Porchlight.xcodeproj" -scheme "Porchlight" -configuration Debug build
```

The build phase `Bundle porchlight CLI` builds the Rust CLI and copies it into the app bundle:

```text
Porchlight.app/Contents/Resources/porchlight
```

## CLI Lookup

The app resolves the CLI in this order:

1. `PORCHLIGHT_CLI_PATH`, if set.
2. Local development binary at `/Users/tyler/Developer/porchlight/cli/target/debug/porchlight`.
3. Bundled app resource named `porchlight`.

## App Behavior

- Uses `NSStatusItem` for the menu bar icon.
- Uses native `NSMenu` and submenus for the dropdown.
- Keeps running when the main window closes.
- Shows as a normal Dock app while the main window is open.
- Switches to accessory mode when the main window closes, hiding the Dock icon while keeping the menu bar item alive.
- App sandboxing is disabled so the CLI can inspect local processes.

## Menu Bar

The menu bar shows active, recent, and pinned servers from `porchlight list --json`.

Each server menu item includes:

- status dot
- port
- inferred server type
- submenu actions

Available actions include:

- open address
- open in Finder
- open in app: Visual Studio Code or Xcode
- copy command
- pin/unpin
- kill
- kill and remove
- start, when a start command exists
- remove

Servers that match a user Group are sectioned under a small disabled group header. The header uses the colour chosen for the Group. Active and inactive/recent servers are grouped until removed.

## Main Window

The main window uses native SwiftUI.

Top tabs:

- Servers
- Groups
- Settings
- About

Servers uses `NavigationSplitView` with:

- native list/sidebar of local servers
- server detail pane
- native swipe actions
- human-readable relative `Last Seen`
- Open, Open in Finder, Open in App, Turn On/Off, Pin/Unpin, and Remove actions

Groups uses `NavigationSplitView` with:

- native list/sidebar of user Groups
- `+` button to create an empty Group
- detail editor for name, colour, command chips, working-directory chips, and priority

The sidebar toggle is removed from split views so the sidebars stay visible in the app UI.

## User Data

The app edits the same files the CLI reads:

```text
~/.config/porchlight/groups.json
~/.local/state/porchlight/state.json
```
