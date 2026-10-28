import AppKit
import ApplicationServices
import os

@MainActor
final class WindowTracker {
    private var lastFocus: [CGWindowID: Date] = [:]
    private var lastActivation: [pid_t: Date] = [:]
    private var observers: [pid_t: AXObserver] = [:]
    private var elements: [CGWindowID: AXUIElement] = [:]
    private var lastWindows: [pid_t: [(WindowInfo, AXUIElement)]] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []

    func start() {
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular { observe(app.processIdentifier) }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
                MainActor.assumeIsolated {
                    guard let pid else { return }
                    self?.lastActivation[pid] = Date()
                    self?.observe(pid)
                    if let el = AX.focusedWindow() { self?.touch(el) }
                }
            })
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
                MainActor.assumeIsolated {
                    guard let pid else { return }
                    self?.lastActivation[pid] = nil
                    self?.removeObserver(pid)
                }
            })
    }

    func observe(_ pid: pid_t) {
        guard observers[pid] == nil else { return }
        let callback: AXObserverCallback = { _, element, _, refcon in
            guard let refcon else { return }
            let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { tracker.touch(element) }
        }
        var observer: AXObserver?
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { return }
        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(observer, app, kAXFocusedWindowChangedNotification as CFString, refcon) == .success else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    func touch(_ el: AXUIElement) {
        guard let id = AX.windowID(el) else { return }
        lastFocus[id] = Date()
    }

    func snapshot() -> [WindowInfo] {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        defer { AXUIElementSetMessagingTimeout(system, 0) }
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let screen = info.compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
        let zOrder = info.compactMap { $0[kCGWindowLayer as String] as? Int == 0 ? $0[kCGWindowNumber as String] as? CGWindowID : nil }
        let windowInfo = Dictionary(
            uniqueKeysWithValues: info.enumerated().compactMap { index, item -> (CGWindowID, (CGRect?, Int))? in
                guard let id = item[kCGWindowNumber as String] as? CGWindowID else { return nil }
                let frame = (item[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) }
                return (id, (frame, index))
            })
        let onScreen = Set(screen)
        var windows: [WindowInfo] = []
        var current: [CGWindowID: AXUIElement] = [:]
        let ownPID = NSRunningApplication.current.processIdentifier
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != ownPID {
            let pid = app.processIdentifier
            guard let appWindows = AX.windows(pid: pid) else {
                Logger(subsystem: "com.epulla.ziran", category: "WindowTracker").notice(
                    "Window snapshot failed for \(app.localizedName ?? "Unknown", privacy: .public) (pid \(pid))")
                for (window, element) in lastWindows[pid] ?? [] where onScreen.contains(window.id) || window.isMinimized {
                    windows.append(window)
                    current[window.id] = element
                }
                continue
            }
            var known: [(WindowInfo, AXUIElement)] = []
            for el in appWindows {
                guard let id = AX.windowID(el), onScreen.contains(id) || AX.isMinimized(el) else { continue }
                let window = windowInfo[id]
                let item = WindowInfo(
                    id: id, pid: app.processIdentifier, bundleId: app.bundleIdentifier ?? "", appName: app.localizedName ?? "", title: AX.title(el),
                    isMinimized: AX.isMinimized(el), frame: window?.0, zOrder: window?.1 ?? .max)
                windows.append(item)
                current[id] = el
                known.append((item, el))
            }
            lastWindows[pid] = known
        }
        elements = current
        let kept = Set(windows.map(\.id))
        lastFocus = lastFocus.filter { kept.contains($0.key) }
        return MRU.order(windows, lastFocus: lastFocus, appActivation: lastActivation, zOrder: zOrder)
    }

    func element(_ id: CGWindowID) -> AXUIElement? { elements[id] }

    private func removeObserver(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }
}
