# Window Resizer

A lightweight macOS menu bar app that resizes and repositions all windows of the previously active application to a chosen layout. Built with Swift and AppKit.

## Features

- **Menu bar app** — runs as a status bar icon with no Dock presence
- **Automatic target detection** — tracks the last active app and applies layouts to its windows
- **Multi-monitor support** — windows are resized relative to the screen they're currently on
- **Move to Display** — gather all windows of an app onto a single display, with auto-detected position labels (Left, Right, Top, Bottom)
- **Global hotkey** — press `Ctrl + Opt + Cmd + W` to open the menu from any app
- **URL scheme** — trigger any command from Alfred, Shortcuts, or the Terminal via `windowresizer://` URLs
- **Open at Login** — toggle launch at login from the menu
- **Six layouts** (with SF Symbol icons):
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

### Move to Display

When multiple monitors are connected, a **Move to Display** submenu appears in the menu. Each display is listed by name with its relative position (e.g., "Built-in Retina Display (Left)"). Select a display to gather all windows of the target app onto that screen (arranged as full screen). You can then apply a different layout from the main menu. The submenu updates automatically when displays are connected or disconnected.

### URL Scheme

Window Resizer registers the `windowresizer://` URL scheme, allowing external apps and scripts to trigger commands. The target app is always the most recently active application (the same app shown in the menu header).

#### Apply a layout

```
windowresizer://layout/{layoutName}
```

| Layout name   | Description    |
|---------------|----------------|
| `leftHalf`    | Left Half      |
| `rightHalf`   | Right Half     |
| `topHalf`     | Top Half       |
| `bottomHalf`  | Bottom Half    |
| `fullScreen`  | Full Screen    |
| `center75`    | Center (75%)   |

#### Move to display

```
windowresizer://move-to-display/{displayIndex}
```

Display indices are zero-based and follow `NSScreen.screens` ordering (index `0` is the primary display).

#### Examples

From **Terminal**:

```bash
# Apply left-half layout to the last active app
open "windowresizer://layout/leftHalf"

# Move all windows to the primary display
open "windowresizer://move-to-display/0"

# Move all windows to the second display
open "windowresizer://move-to-display/1"
```

From **Alfred**: Create a workflow with a keyword trigger connected to an "Open URL" action. Set the URL to one of the patterns above — e.g., `windowresizer://layout/fullScreen`.

From **macOS Shortcuts**: Add an "Open URL" action and enter the URL — e.g., `windowresizer://layout/center75`. You can assign a keyboard shortcut to the Shortcut in System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts.

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
    ├── Info.plist            # URL scheme registration
    ├── main.swift            # App entry point (NSApplication setup)
    ├── AppDelegate.swift     # Menu bar UI, app tracking, global hotkey, URL handling, login item
    ├── WindowManager.swift   # Layout definitions and AXUIElement window manipulation
    └── Assets.xcassets/      # App icon and accent color
```

## License

MIT
