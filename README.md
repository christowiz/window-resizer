# Window Resizer

A lightweight macOS menu bar app that resizes and repositions all windows of the previously active application to a chosen layout. Built with Swift and AppKit.

## Features

- **Menu bar app** — runs as a status bar icon with no Dock presence
- **Automatic target detection** — tracks the last active app and applies layouts to its windows
- **Multi-monitor support** — windows are resized relative to the screen they're currently on
- **Global hotkey** — press `Ctrl + Opt + Cmd + W` to open the menu from any app
- **Open at Login** — toggle launch at login from the menu
- **Six layouts:**
  - Left Half / Right Half
  - Top Half / Bottom Half
  - Full Screen
  - Center (75%)

## Requirements

- macOS 15.6 or later
- Xcode 26+ (to build from source)
- **Accessibility permission** — the app must be granted access in System Settings > Privacy & Security > Accessibility

## Build & Install

### From Xcode

1. Open `Window Resizer/Window Resizer.xcodeproj` in Xcode
2. Select the **Release** build configuration (Product > Scheme > Edit Scheme > Run > Release)
3. Build with **Cmd + B**
4. Locate the built app via Product > Show Build Folder in Finder (`Products/Release/`)
5. Copy `Window Resizer.app` to `/Applications`

### From the command line

```bash
cd "Window Resizer"
xcodebuild -scheme "Window Resizer" -configuration Release build

# Copy to /Applications
rm -rf /Applications/Window\ Resizer.app
cp -R ~/Library/Developer/Xcode/DerivedData/Window_Resizer-*/Build/Products/Release/Window\ Resizer.app /Applications/
```

## Usage

1. Launch `Window Resizer.app` — a split-rectangle icon appears in the menu bar
2. Switch to the app whose windows you want to resize
3. Click the menu bar icon (or press `Ctrl + Opt + Cmd + W`)
4. Select a layout — all standard windows of the target app are resized and repositioned

## Accessibility Permission

On first launch, the app will prompt for Accessibility access. If windows aren't moving:

1. Open **System Settings > Privacy & Security > Accessibility**
2. Find "Window Resizer" and ensure it is toggled **on**
3. If it was already on, toggle it **off** and then **on** again

> **Note:** Building from source with "Sign to Run Locally" (ad-hoc signing) generates a new code signature each time, which invalidates the Accessibility permission. To avoid re-granting permission after every rebuild, configure a Developer signing identity in Xcode under Signing & Capabilities.

## Project Structure

```
Window Resizer/
├── Window Resizer.xcodeproj
└── Window Resizer/
    ├── main.swift            # App entry point (NSApplication setup)
    ├── AppDelegate.swift     # Menu bar UI, app tracking, global hotkey, login item
    ├── WindowManager.swift   # Layout definitions and AXUIElement window manipulation
    └── Assets.xcassets/      # App icon and accent color
```

## License

MIT
