import AppKit
import CoreGraphics

@MainActor
final class SwitcherTap {
    private static let digits: [Int64] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
    private static let keypadDigits: [Int64] = [83, 84, 85, 86, 87, 88, 89, 91, 92]
    // ANSI keycodes for A–Z without Q and W, in Switcher.shortcutLabels order.
    private static let letters: [Int64] = [0, 11, 8, 2, 14, 3, 5, 4, 34, 38, 40, 37, 46, 45, 31, 35, 15, 1, 17, 32, 9, 7, 16, 6]
    private static let resizeKeys: [Int64: WindowResizer.Command] = [
        123: .layout(.leftHalf), 124: .layout(.rightHalf), 126: .layout(.topHalf), 125: .layout(.bottomHalf),
        32: .layout(.topLeft), 34: .layout(.topRight), 38: .layout(.bottomLeft), 40: .layout(.bottomRight),
        36: .layout(.maximize), 3: .layout(.maximize), 8: .layout(.center), 51: .restore,
    ]
    private static let displayKeys: [Int64: WindowResizer.Command] = [124: .nextDisplay, 123: .previousDisplay]
    var switcher = Switcher()
    private let tracker: WindowTracker
    private let resizer: WindowResizer
    private var panel: SwitcherPanel!
    private var tap: CFMachPort?
    private var previousApp: NSRunningApplication?
    private var pendingClose: [WindowInfo] = []
    private var pendingQuit: pid_t?
    private var closePoll: Timer?
    private var closeChecksRemaining = 0

    init(tracker: WindowTracker, resizer: WindowResizer) {
        self.tracker = tracker
        self.resizer = resizer
        panel = SwitcherPanel { [weak self] key in self?.run(self?.switcher.handle(key) ?? .none) }
    }

    func start() -> Bool {
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<SwitcherTap>.fromOpaque(refcon).takeUnretainedValue()
            let eventPointer = UInt(bitPattern: Unmanaged.passUnretained(event).toOpaque())
            let swallow = MainActor.assumeIsolated { tap.handle(proxy, type: type, eventPointer: eventPointer) }
            return swallow ? nil : Unmanaged.passUnretained(event)
        }
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback,
                userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        return true
    }

    private func handle(_ proxy: CGEventTapProxy, type: CGEventType, eventPointer: UInt) -> Bool {
        let event = Unmanaged<CGEvent>.fromOpaque(UnsafeRawPointer(bitPattern: eventPointer)!).takeUnretainedValue()
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        let flags = event.flags
        if type == .keyDown {
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            let alternate = flags.contains(.maskAlternate)
            let modifier = flags.contains(.maskCommand) || flags.contains(.maskControl)
            if Settings.windowShortcuts && switcher.mode == .closed && flags.contains(.maskControl) && alternate && !flags.contains(.maskShift),
                let command = flags.contains(.maskCommand) ? Self.displayKeys[keycode] : Self.resizeKeys[keycode]
            {
                resizer.perform(command)
                return true
            }
            // 50 is ANSI grave; ISO keyboards report the same key as 10.
            if (keycode == 50 || keycode == 10) && alternate && !modifier && switcher.mode != .list {
                if switcher.mode == .closed {
                    previousApp = NSWorkspace.shared.frontmostApplication
                    if let pid = previousApp?.processIdentifier {
                        if let focused = AX.focusedWindow() { tracker.touch(focused) }
                        let snapshot = tracker.snapshot()
                        let draft = templateDisplay().map { templateSlots(snapshot, in: $0) } ?? []
                        run(switcher.open(snapshot, app: pid, quickNav: Settings.quickNav, templates: Settings.layoutTemplates, draft: draft))
                    }
                } else {
                    run(switcher.handle(flags.contains(.maskShift) ? .previousWindow : .nextWindow))
                }
                return true
            }
            if keycode == 48 && alternate && !modifier {
                if switcher.mode == .closed {
                    previousApp = NSWorkspace.shared.frontmostApplication
                    if let focused = AX.focusedWindow() { tracker.touch(focused) }
                    let snapshot = tracker.snapshot()
                    let draft = templateDisplay().map { templateSlots(snapshot, in: $0) } ?? []
                    run(switcher.open(snapshot, quickNav: Settings.quickNav, templates: Settings.layoutTemplates, draft: draft))
                } else if switcher.mode == .strip || switcher.mode == .dropdown {
                    run(switcher.handle(flags.contains(.maskShift) ? .shiftTab : .tab))
                }
                return true
            }
            if switcher.mode != .closed && switcher.mode != .list && flags.contains(.maskShift) && !modifier,
                let index = Self.digits.firstIndex(of: keycode) ?? Self.keypadDigits.firstIndex(of: keycode)
            {
                run(switcher.handle(.openQuickNav(index)))
                return true
            }
            if switcher.mode != .closed && flags.contains(.maskCommand),
                let index = Self.digits.firstIndex(of: keycode) ?? Self.keypadDigits.firstIndex(of: keycode)
            {
                run(switcher.handle(switcher.mode == .list ? .jump(index) : .applyTemplate(index)))
                return true
            }
            if switcher.mode != .closed && switcher.mode != .list && (flags.contains(.maskControl) || alternate),
                let index = Self.digits.firstIndex(of: keycode) ?? Self.keypadDigits.firstIndex(of: keycode)
            {
                run(switcher.handle(.jump(index)))
                return true
            }
            if (switcher.mode == .strip || switcher.mode == .dropdown) && alternate && !modifier && !flags.contains(.maskShift),
                let index = Self.letters.firstIndex(of: keycode)
            {
                run(switcher.handle(.jump(Self.digits.count + index)))
                return true
            }
            // Plain W must stay typeable in the search field, so the list uses ⌘W.
            if keycode == 13 && switcher.mode != .closed && (switcher.mode == .list ? flags.contains(.maskCommand) : alternate && !modifier) {
                run(switcher.handle(.closeWindow))
                return true
            }
            // Plain = must stay typeable too, so the list pins with ⌘=.
            if keycode == 24 && switcher.mode == .list && flags.contains(.maskCommand) {
                if let id = switcher.selection?.id { run(switcher.handle(.pin(id))) }
                return true
            }
            guard switcher.mode == .strip || switcher.mode == .dropdown || switcher.mode == .quickNav || switcher.mode == .templates else { return false }
            // ⌘↑↓ reorders only inside the boxes; swallow it in the strip and dropdown so it doesn't act as a plain arrow.
            if (keycode == 126 || keycode == 125) && flags.contains(.maskCommand) {
                let offset = keycode == 126 ? -1 : 1
                if switcher.mode == .quickNav {
                    run(switcher.handle(.moveQuickNav(from: switcher.quickNavRow, to: switcher.quickNavRow + offset)))
                } else if switcher.mode == .templates {
                    run(switcher.handle(.moveTemplate(from: switcher.templatesRow, to: switcher.templatesRow + offset)))
                }
                return true
            }
            let key: Switcher.Key?
            switch keycode {
            case 126: key = .up
            case 125: key = .down
            case 124: key = .right
            case 123: key = .left
            case 27 where !modifier: key = .bookmark
            case 36: key = .enter
            case 53: key = .escape
            case 12 where !modifier: key = .quitApp
            case 24 where !modifier:
                if switcher.mode == .templates { run(switcher.handle(.saveTemplate)); return true }
                if let id = switcher.selection?.id { run(switcher.handle(.pin(id))) }
                return true
            default: key = nil
            }
            if let key { run(switcher.handle(key)); return true }
        } else if type == .flagsChanged && !flags.contains(.maskAlternate)
            && (switcher.mode == .strip || switcher.mode == .dropdown || switcher.mode == .quickNav || switcher.mode == .templates)
        {
            run(switcher.handle(.optionUp))
            return true
        }
        return false
    }

    private func run(_ effect: Switcher.Effect) {
        switch effect {
        case .update: panel.show(switcher, bookmark: bookmarkCandidate())
        case .focus(let window):
            stopClosePoll()
            panel.hide()
            if let element = tracker.element(window.id) {
                AX.focus(element)
                tracker.touch(element)
            } else {
                NSRunningApplication(processIdentifier: window.pid)?.activate()
            }
        case .closeWindow(let window): close([window], checks: 10)
        case .closeWindows(let windows): close(windows, checks: 20)
        case .quitApp(let pid):
            guard closePoll == nil else { break }
            guard let app = NSRunningApplication(processIdentifier: pid), app.terminate() else {
                dismissForCloseFailure(pid)
                break
            }
            pendingQuit = pid
            // Apps like Chrome can take a couple of seconds to exit; a save prompt keeps them alive until we give up.
            startClosePoll(checks: 30) { [weak self] in self?.checkQuit(app) }
        case .close:
            stopClosePoll()
            let wasKey = panel.isKeyWindow
            panel.hide()
            if wasKey { previousApp?.activate(options: []) }
        case .open(let url):
            stopClosePoll()
            panel.hide()
            NSWorkspace.shared.open(url)
        case .toggleBookmark(let window):
            // Finder lookup runs AppleScript (and its first-use permission prompt); doing that inside the event tap callback gets the tap disabled.
            Task { [weak self] in
                guard let self else { return }
                guard let url = bookmarkURL(for: window, askFinder: true) else {
                    NSSound.beep()
                    return
                }
                var urls = Settings.quickNav
                if let index = urls.firstIndex(of: url) { urls.remove(at: index) } else { urls.append(url) }
                Settings.quickNav = urls
                run(switcher.handle(.quickNavChanged(Settings.quickNav)))
            }
        case .removeBookmark(let url):
            Settings.quickNav.removeAll { $0 == url }
            run(switcher.handle(.quickNavChanged(Settings.quickNav)))
        case .saveTemplate:
            saveTemplate()
        case .removeTemplate(let template):
            Settings.layoutTemplates.removeAll { $0 == template }
            run(switcher.handle(.templatesChanged(Settings.layoutTemplates)))
        case .applyTemplate(let template):
            apply(template)
        case .reorderQuickNav(let urls):
            Settings.quickNav = urls
            run(switcher.handle(.quickNavChanged(Settings.quickNav)))
        case .reorderTemplates(let values):
            Settings.layoutTemplates = values
            run(switcher.handle(.templatesChanged(Settings.layoutTemplates)))
        case .none: break
        }
    }

    private func templateDisplay() -> CGRect? {
        guard let screen = panel.screen ?? NSScreen.main, let primaryMaxY = NSScreen.screens.first?.frame.maxY else { return nil }
        return AX.flip(screen.visibleFrame, primaryMaxY: primaryMaxY)
    }

    private func saveTemplate() {
        guard let display = templateDisplay() else { NSSound.beep(); return }
        let snapshot = tracker.snapshot()
        let slots = templateSlots(snapshot, in: display)
        guard !slots.isEmpty else { NSSound.beep(); return }
        if let index = Settings.layoutTemplates.firstIndex(where: { Set($0.slots) == Set(slots) }) {
            NSSound.beep()
            run(switcher.handle(.selectTemplate(index)))
            return
        }
        let names = snapshot.filter { window in slots.contains { $0.bundleID == window.bundleId } }
        let template = LayoutTemplate(
            name: slots.compactMap { slot in names.first { $0.bundleId == slot.bundleID }?.appName }.joined(separator: " · "), slots: slots)
        Settings.layoutTemplates.append(template)
        run(switcher.handle(.templatesChanged(Settings.layoutTemplates)))
    }

    private func templateSlots(_ snapshot: [WindowInfo], in display: CGRect) -> [LayoutTemplate.Slot] {
        let windows = snapshot.sorted { $0.zOrder < $1.zOrder }.compactMap { window -> (String, CGRect)? in
            guard !window.isMinimized, let frame = window.frame,
                display.contains(CGPoint(x: frame.midX, y: frame.midY))
            else { return nil }
            return (window.bundleId, frame)
        }
        return Layout.templateSlots(windows, in: display)
    }

    private func apply(_ template: LayoutTemplate) {
        guard let display = templateDisplay() else { return }
        panel.hide()
        Task { @MainActor [weak self] in
            guard let self else { return }
            var placed: [AXUIElement] = []
            for slot in template.slots {
                let deadline = Date().addingTimeInterval(5)
                var app = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == slot.bundleID }
                if app == nil {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: slot.bundleID) {
                        app = await withCheckedContinuation { continuation in
                            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { running, _ in
                                continuation.resume(returning: running)
                            }
                        }
                    }
                }
                guard let app else { continue }
                while Date() < deadline {
                    if let window = tracker.snapshot().first(where: { $0.pid == app.processIdentifier && !$0.isMinimized }),
                        let element = tracker.element(window.id)
                    {
                        AX.setFrame(element, Layout.frame(slot.action, current: .zero, in: display))
                        placed.append(element)
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(min(100, max(1, Int(deadline.timeIntervalSinceNow * 1000)))))
                }
            }
            for element in placed.reversed() {
                AX.focus(element)
                tracker.touch(element)
            }
        }
    }

    private func bookmarkCandidate() -> URL? {
        guard switcher.mode == .strip || switcher.mode == .dropdown, let window = switcher.selection else { return nil }
        return bookmarkURL(for: window, askFinder: false)
    }

    private func bookmarkURL(for window: WindowInfo, askFinder: Bool) -> URL? {
        if let element = tracker.element(window.id), let document = AX.document(element) { return document }
        if window.bundleId == "com.apple.finder" { return askFinder ? finderFolder(titled: window.title) : nil }
        return NSRunningApplication(processIdentifier: window.pid)?.bundleURL
    }

    // Finder exposes no folder through Accessibility, so ask it over AppleScript and match the window by title.
    private func finderFolder(titled title: String) -> URL? {
        let source = """
            tell application "Finder"
                set output to ""
                repeat with finderWindow in Finder windows
                    try
                        set output to output & (name of finderWindow) & tab & (POSIX path of (target of finderWindow as alias)) & linefeed
                    end try
                end repeat
                return output
            end tell
            """
        guard let output = NSAppleScript(source: source)?.executeAndReturnError(nil).stringValue else { return nil }
        let paths = output.split(separator: "\n").compactMap { line -> String? in
            let parts = line.split(separator: "\t", maxSplits: 1)
            return parts.count == 2 && parts[0] == title ? String(parts[1]) : nil
        }
        return paths.count == 1 ? URL(fileURLWithPath: paths[0]) : nil
    }

    private func startClosePoll(checks: Int, _ check: @escaping @MainActor () -> Void) {
        closeChecksRemaining = checks
        closePoll = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated { check() }
        }
    }

    private func close(_ windows: [WindowInfo], checks: Int) {
        guard closePoll == nil, let pid = windows.first?.pid else { return }
        var pressed: [WindowInfo] = []
        for window in windows {
            if let element = tracker.element(window.id), AX.close(element) { pressed.append(window) }
        }
        guard pressed.count == windows.count else {
            dismissForCloseFailure(pid)
            return
        }
        pendingClose = pressed
        startClosePoll(checks: checks) { [weak self] in self?.checkClose() }
    }

    private func checkClose() {
        guard let pid = pendingClose.first?.pid else { return }
        let closed = pendingClose.filter { AX.windowExists($0.id, pid: $0.pid) == false }
        pendingClose.removeAll { closed.contains($0) }
        let emptied = pendingClose.isEmpty
        if emptied { stopClosePoll() }
        for window in closed { run(switcher.handle(.windowClosed(window.id))) }
        if !emptied && closePoll != nil { giveUpIfExhausted(pid) }
    }

    private func checkQuit(_ app: NSRunningApplication) {
        guard pendingQuit == app.processIdentifier else { return }
        if app.isTerminated {
            stopClosePoll()
            run(switcher.handle(.appQuit(app.processIdentifier)))
        } else {
            giveUpIfExhausted(app.processIdentifier)
        }
    }

    private func giveUpIfExhausted(_ pid: pid_t) {
        closeChecksRemaining -= 1
        if closeChecksRemaining == 0 { dismissForCloseFailure(pid) }
    }

    private func dismissForCloseFailure(_ pid: pid_t) {
        stopClosePoll()
        run(switcher.handle(.escape))
        NSRunningApplication(processIdentifier: pid)?.activate(options: [])
    }

    private func stopClosePoll() {
        closePoll?.invalidate()
        closePoll = nil
        pendingClose = []
        pendingQuit = nil
    }
}
