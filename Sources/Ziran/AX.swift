import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
@discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError

enum AX {
    static func windowID(_ el: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(el, &id) == .success ? id : nil
    }

    static func windows(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
            let windows = value as? [AXUIElement]
        else { return [] }
        return windows.filter {
            var subrole: CFTypeRef?
            return AXUIElementCopyAttributeValue($0, kAXSubroleAttribute as CFString, &subrole) == .success
                && (subrole as? String) == kAXStandardWindowSubrole as String
        }
    }

    static func title(_ el: AXUIElement) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &value) == .success else { return "" }
        return value as? String ?? ""
    }

    static func isMinimized(_ el: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXMinimizedAttribute as CFString, &value) == .success else { return false }
        return value as? Bool ?? false
    }

    static func frame(_ el: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &position) == .success,
            AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &size) == .success,
            let p = position, let s = size
        else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &origin), AXValueGetValue(s as! AXValue, .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    static func setFrame(_ el: AXUIElement, _ rect: CGRect) {
        guard let pid = pid(of: el) else { return }
        let app = AXUIElementCreateApplication(pid)
        var enhanced: CFTypeRef?
        AXUIElementCopyAttributeValue(app, "AXEnhancedUserInterface" as CFString, &enhanced)
        // Chrome/Electron animate resizes and drop position writes while enhanced UI is on.
        let wasEnhanced = enhanced as? Bool ?? false
        if wasEnhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, false as CFTypeRef) }
        var size = rect.size
        var position = rect.origin
        let sizeValue = AXValueCreate(.cgSize, &size)
        let positionValue = AXValueCreate(.cgPoint, &position)
        if let sizeValue, let positionValue {
            AXUIElementSetAttributeValue(el, kAXSizeAttribute as CFString, sizeValue)
            AXUIElementSetAttributeValue(el, kAXPositionAttribute as CFString, positionValue)
            AXUIElementSetAttributeValue(el, kAXSizeAttribute as CFString, sizeValue)
        }
        if wasEnhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, true as CFTypeRef) }
    }

    static func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value) == .success else { return nil }
        return (value as! AXUIElement)
    }

    static func focus(_ el: AXUIElement) {
        if isMinimized(el) { AXUIElementSetAttributeValue(el, kAXMinimizedAttribute as CFString, false as CFTypeRef) }
        if let pid = pid(of: el) { NSRunningApplication(processIdentifier: pid)?.activate() }
        AXUIElementPerformAction(el, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(el, kAXMainAttribute as CFString, true as CFTypeRef)
    }

    static func close(_ el: AXUIElement) -> Bool {
        var button: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXCloseButtonAttribute as CFString, &button) == .success, let button else { return false }
        return AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString) == .success
    }

    static func windowExists(_ id: CGWindowID, pid: pid_t) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value) == .success,
            let windows = value as? [AXUIElement]
        else { return nil }
        var unknown = false
        for window in windows {
            guard let windowID = windowID(window) else { unknown = true; continue }
            if windowID == id { return true }
        }
        return unknown ? nil : false
    }

    static func flip(_ rect: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(x: rect.origin.x, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func pid(of el: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(el, &pid) == .success ? pid : nil
    }
}
