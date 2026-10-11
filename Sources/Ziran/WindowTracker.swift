import AppKit
import ApplicationServices

@MainActor
final class WindowTracker {
    private var lastFocus: [CGWindowID: Date] = [:]
    private var lastActivation: [pid_t: Date] = [:]
    private var observers: [pid_t: AXObserver] = [:]
    private var elements: [CGWindowID: AXUIElement] = [:]
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
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let screen = info.compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
        let zOrder = info.compactMap { $0[kCGWindowLayer as String] as? Int == 0 ? $0[kCGWindowNumber as String] as? CGWindowID : nil }
        let onScreen = Set(screen)
        var windows: [WindowInfo] = []
        var current: [CGWindowID: AXUIElement] = [:]
        let ownPID = NSRunningApplication.current.processIdentifier
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != ownPID {
            for el in AX.windows(pid: app.processIdentifier) {
                guard let id = AX.windowID(el), onScreen.contains(id) || AX.isMinimized(el) else { continue }
                windows.append(
                    WindowInfo(
                        id: id, pid: app.processIdentifier, bundleId: app.bundleIdentifier ?? "", appName: app.localizedName ?? "", title: AX.title(el),
                        isMinimized: AX.isMinimized(el)))
                current[id] = el
            }
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
