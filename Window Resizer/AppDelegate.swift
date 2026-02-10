import AppKit
import Carbon
import ServiceManagement

// MARK: - Carbon Hot Key Callback (must be a free function for C interop)

private func hotKeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        (NSApp.delegate as? AppDelegate)?.showMenu()
    }
    return noErr
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private var previousApp: NSRunningApplication?
    private var hotKeyRef: EventHotKeyRef?
    private var targetInfoItem: NSMenuItem!
    private var displaySubmenuItem: NSMenuItem!
    private var loginItem: NSMenuItem!

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()
        trackActiveApp()
        setupStatusBar()
        registerGlobalHotKey()
        observeScreenChanges()
    }

    // MARK: - Accessibility

    private func requestAccessibilityIfNeeded() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Active App Tracking

    private func trackActiveApp() {
        // Seed with the current frontmost app
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }

        // Update whenever a different app activates
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let activated = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
            ] as? NSRunningApplication else { return }

            if activated.bundleIdentifier != Bundle.main.bundleIdentifier {
                self?.previousApp = activated
            }
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.split.2x1",
                accessibilityDescription: "Window Resizer"
            )
        }

        let menu = NSMenu()
        menu.delegate = self

        // Dynamic header showing the target app
        targetInfoItem = NSMenuItem(title: "No target app", action: nil, keyEquivalent: "")
        targetInfoItem.isEnabled = false
        menu.addItem(targetInfoItem)
        menu.addItem(NSMenuItem.separator())

        // Layout items
        for (index, layout) in Layout.allCases.enumerated() {
            let item = NSMenuItem(
                title: layout.menuTitle,
                action: #selector(layoutSelected(_:)),
                keyEquivalent: String(index + 1)
            )
            item.image = NSImage(systemSymbolName: layout.icon, accessibilityDescription: layout.menuTitle)
            item.keyEquivalentModifierMask = []
            item.image = NSImage(systemSymbolName: layout.icon, accessibilityDescription: layout.menuTitle)
            item.representedObject = layout
            item.target = self
            menu.addItem(item)

            if layout == .bottomHalf || layout == .center75 {
                menu.addItem(NSMenuItem.separator())
            }
        }

        // Move to Display submenu (populated once and updated on screen changes)
        displaySubmenuItem = NSMenuItem(
            title: "Move to Display",
            action: nil,
            keyEquivalent: ""
        )
        displaySubmenuItem.submenu = NSMenu()
        menu.addItem(displaySubmenuItem)
        rebuildDisplaySubmenu()

        // Open at Login
        menu.addItem(NSMenuItem.separator())
        loginItem = NSMenuItem(
            title: "Open at Login",
            action: #selector(toggleLoginItem(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        menu.addItem(loginItem)

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Window Resizer",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Update the header to show the current target app
        if let app = previousApp, let name = app.localizedName {
            targetInfoItem.title = "Target: \(name)"
        } else {
            targetInfoItem.title = "No target app"
        }

        // Update login item checkmark
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: - Display Submenu

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildDisplaySubmenu()
        }
    }

    private func rebuildDisplaySubmenu() {
        guard let submenu = displaySubmenuItem.submenu else { return }
        submenu.removeAllItems()

        let screens = NSScreen.screens

        // Hide the submenu when there is only one display
        displaySubmenuItem.isHidden = screens.count <= 1

        let positionIcons = Self.positionLabels(for: screens)

        for (index, screen) in screens.enumerated() {
            let icon = positionIcons[index]
            let title = "\(screen.localizedName)"
            let item = NSMenuItem(
                title: title,
                action: #selector(displaySelected(_:)),
                keyEquivalent: ""
            )
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
            item.tag = index
            item.target = self
            submenu.addItem(item)
        }
    }

    /// Determine a position label (e.g. "Left", "Right", "Center") for each
    /// screen based on its horizontal and vertical placement.
    private static func positionLabels(for screens: [NSScreen]) -> [String] {
        guard screens.count > 1 else {
            return screens.map { _ in "Primary" }
        }

        let origins = screens.map { $0.frame.origin }

        let uniqueX = Set(origins.map { $0.x }).count
        let uniqueY = Set(origins.map { $0.y }).count

        // Sort indices by x then y to determine relative position
        let sortedByX = origins.enumerated().sorted { $0.element.x < $1.element.x }

        var labels = [Int: String]()

//        if isHorizontal && !isVertical {
            // Pure horizontal arrangement
            for (rank, entry) in sortedByX.enumerated() {
                if rank == 0 {
                    labels[entry.offset] = "inset.filled.leadinghalf.arrow.leading.rectangle"
                } else if rank == sortedByX.count - 1 {
                    labels[entry.offset] = "inset.filled.trailinghalf.arrow.trailing.rectangle"
                } else {
                    labels[entry.offset] = "inset.filled.center.rectangle"
                }
            }
//        } else if isVertical && !isHorizontal {
//            // Pure vertical arrangement (NSScreen y: bottom-left origin)
//            for (rank, entry) in sortedByY.enumerated() {
//                if rank == 0 {
//                    labels[entry.offset] = "square.tophalf.filled"
//                } else if rank == sortedByY.count - 1 {
//                    labels[entry.offset] = "square.bottomhalf.filled"
//                } else {
//                    labels[entry.offset] = "arrow.right.and.line.vertical.and.arrow.left"
//                }
//            }
//        } else {
//            // Mixed arrangement — combine horizontal and vertical labels
//            let xRank = Dictionary(uniqueKeysWithValues: sortedByX.enumerated().map { ($1.offset, $0) })
//            let yRank = Dictionary(uniqueKeysWithValues: sortedByY.enumerated().map { ($1.offset, $0) })
//
//            for i in screens.indices {
//                var parts: [String] = []
//
//                if let xr = xRank[i] {
//                    if xr == 0 { parts.append("Left") }
//                    else if xr == screens.count - 1 { parts.append("Right") }
//                }
//                if let yr = yRank[i] {
//                    if yr == 0 { parts.append("Top") }
//                    else if yr == screens.count - 1 { parts.append("Bottom") }
//                }
//
//                labels[i] = parts.isEmpty ? "Center" : parts.joined(separator: " ")
//            }
//        }

        return screens.indices.map { labels[$0] ?? "" }
    }

    // MARK: - Menu Actions

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not update login item"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func layoutSelected(_ sender: NSMenuItem) {
        guard let layout = sender.representedObject as? Layout,
              let targetApp = previousApp else { return }

        WindowManager.applyLayout(layout, to: targetApp)

        // Return focus to the target app
        targetApp.activate()
    }

    @objc private func displaySelected(_ sender: NSMenuItem) {
        let screens = NSScreen.screens
        guard sender.tag < screens.count,
              let targetApp = previousApp else { return }

        let targetScreen = screens[sender.tag]
        WindowManager.moveAllWindows(of: targetApp, to: targetScreen)

        // Return focus to the target app
        targetApp.activate()
    }

    // MARK: - URL Scheme Handling

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleURL(url)
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "windowresizer",
              let targetApp = previousApp else { return }

        let command = url.host ?? ""
        let argument = url.pathComponents.count > 1 ? url.pathComponents[1] : ""

        switch command {
        case "layout":
            guard let layout = Layout(rawValue: argument) else { return }
            WindowManager.applyLayout(layout, to: targetApp)
            targetApp.activate()

        case "move-to-display":
            guard let index = Int(argument),
                  index >= 0,
                  index < NSScreen.screens.count else { return }
            let targetScreen = NSScreen.screens[index]
            WindowManager.moveAllWindows(of: targetApp, to: targetScreen)
            targetApp.activate()

        default:
            break
        }
    }

    // MARK: - Global Hot Key (Ctrl+Opt+Cmd+W)

    func showMenu() {
        statusItem.button?.performClick(nil)
    }

    private func registerGlobalHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyCallback,
            1,
            &eventType,
            nil,
            nil
        )

        // Ctrl + Opt + Cmd + W
        let hotKeyID = EventHotKeyID(signature: OSType(0x57524553), id: UInt32(1))
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let keyCode = UInt32(kVK_ANSI_W)

        RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetEventDispatcherTarget(), 0, &hotKeyRef
        )
    }
}
