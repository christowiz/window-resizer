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
    private var loginItem: NSMenuItem!

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()
        trackActiveApp()
        setupStatusBar()
        registerGlobalHotKey()
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
            item.keyEquivalentModifierMask = []
            item.representedObject = layout
            item.target = self
            menu.addItem(item)

            if layout == .bottomHalf || layout == .center75 {
                menu.addItem(NSMenuItem.separator())
            }
        }

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
