import AppKit
import ApplicationServices

// MARK: - Layout

enum Layout: String, CaseIterable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case fullScreen
    case center75

    var menuTitle: String {
        switch self {
        case .leftHalf:   return "Left Half"
        case .rightHalf:  return "Right Half"
        case .topHalf:    return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .fullScreen: return "Full Screen"
        case .center75:   return "Center (75%)"
        }
    }

    var icon: String {
        switch self {
        case .leftHalf:   return "rectangle.lefthalf.filled"
        case .rightHalf:  return "rectangle.righthalf.filled"
        case .topHalf:    return "rectangle.tophalf.filled"
        case .bottomHalf: return "rectangle.bottomhalf.filled"
        case .fullScreen: return "rectangle.inset.filled"
        case .center75:   return "rectangle.center.inset.filled"
        }
    }

    /// Calculate the target frame in AX coordinates (top-left origin).
    func frame(for visibleFrame: NSRect, primaryScreenHeight: CGFloat) -> CGRect {
        // Convert NSScreen (bottom-left origin) to AX (top-left origin)
        let x = visibleFrame.origin.x
        let y = primaryScreenHeight - visibleFrame.origin.y - visibleFrame.height
        let w = visibleFrame.width
        let h = visibleFrame.height

        switch self {
        case .leftHalf:
            let hw = floor(w / 2)
            return CGRect(x: x, y: y, width: hw, height: h)
        case .rightHalf:
            let hw = floor(w / 2)
            return CGRect(x: x + hw, y: y, width: hw, height: h)
        case .topHalf:
            let hh = floor(h / 2)
            return CGRect(x: x, y: y, width: w, height: hh)
        case .bottomHalf:
            let hh = floor(h / 2)
            return CGRect(x: x, y: y + hh, width: w, height: hh)
        case .fullScreen:
            return CGRect(x: x, y: y, width: w, height: h)
        case .center75:
            let cw = floor(w * 0.75)
            let ch = floor(h * 0.75)
            return CGRect(
                x: x + floor((w - cw) / 2),
                y: y + floor((h - ch) / 2),
                width: cw,
                height: ch
            )
        }
    }
}

// MARK: - Window Manager

enum WindowManager {

    /// Apply a layout to all standard windows of the given application.
    @discardableResult
    static func applyLayout(_ layout: Layout, to app: NSRunningApplication) -> Int {
        guard let primaryScreen = NSScreen.screens.first else { return 0 }
        let primaryHeight = primaryScreen.frame.height
        let appRef = AXUIElementCreateApplication(app.processIdentifier)

        guard let windows = copyWindows(from: appRef) else { return 0 }

        var resized = 0

        for window in windows {
            guard isStandardWindow(window) else { continue }
            guard let position = getPosition(of: window) else { continue }

            let screen = screenForPoint(position, primaryHeight: primaryHeight)
                ?? NSScreen.main
                ?? primaryScreen

            let targetFrame = layout.frame(
                for: screen.visibleFrame,
                primaryScreenHeight: primaryHeight
            )

            setPosition(of: window, to: targetFrame.origin)
            setSize(of: window, to: targetFrame.size)
            resized += 1
        }

        return resized
    }

    /// Move all standard windows of the given application to the specified
    /// screen, applying the given layout on that screen.
    @discardableResult
    static func moveAllWindows(
        of app: NSRunningApplication,
        to targetScreen: NSScreen,
        layout: Layout = .leftHalf
    ) -> Int {
        guard let primaryScreen = NSScreen.screens.first else { return 0 }
        let primaryHeight = primaryScreen.frame.height
        let appRef = AXUIElementCreateApplication(app.processIdentifier)

        guard let windows = copyWindows(from: appRef) else { return 0 }

        let targetFrame = layout.frame(
            for: targetScreen.visibleFrame,
            primaryScreenHeight: primaryHeight
        )

        var moved = 0

        for window in windows {
            guard isStandardWindow(window) else { continue }
            setPosition(of: window, to: targetFrame.origin)
            setSize(of: window, to: targetFrame.size)
            moved += 1
        }

        return moved
    }

    // MARK: - AX Helpers

    private static func copyWindows(from appRef: AXUIElement) -> [AXUIElement]? {
        var ref: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appRef, kAXWindowsAttribute as CFString, &ref
        )
        guard result == .success else { return nil }
        return ref as? [AXUIElement]
    }

    private static func isStandardWindow(_ window: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window, kAXSubroleAttribute as CFString, &ref
        ) == .success else { return false }

        return (ref as? String) == (kAXStandardWindowSubrole as String)
    }

    private static func getPosition(of window: AXUIElement) -> CGPoint? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window, kAXPositionAttribute as CFString, &ref
        ) == .success else { return nil }

        var point = CGPoint.zero
        AXValueGetValue(ref as! AXValue, .cgPoint, &point)
        return point
    }

    private static func setPosition(of window: AXUIElement, to point: CGPoint) {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    private static func setSize(of window: AXUIElement, to size: CGSize) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    // MARK: - Screen Helpers

    /// Find which screen contains the given point (in AX top-left coordinates).
    private static func screenForPoint(
        _ point: CGPoint,
        primaryHeight: CGFloat
    ) -> NSScreen? {
        for screen in NSScreen.screens {
            let f = screen.frame
            // Convert screen frame to AX coordinates
            let axOriginY = primaryHeight - f.origin.y - f.height
            let axRect = CGRect(x: f.origin.x, y: axOriginY, width: f.width, height: f.height)

            if axRect.contains(point) {
                return screen
            }
        }
        return nil
    }
}
