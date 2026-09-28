import AppKit
import CoreGraphics

@MainActor
final class SwitcherTap {
    private static let digits: [Int64] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
    var switcher = Switcher()
    private let tracker: WindowTracker
    private var panel: SwitcherPanel!
    private var tap: CFMachPort?
    private var previousApp: NSRunningApplication?
    private var pendingClose: CGWindowID?
    private var pendingQuit: pid_t?
    private var closePoll: Timer?
    private var closeChecksRemaining = 0

    init(tracker: WindowTracker) {
        self.tracker = tracker
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
            // 50 is ANSI grave; ISO keyboards report the same key as 10.
            if (keycode == 50 || keycode == 10) && alternate && !modifier && switcher.mode != .list {
                if switcher.mode == .closed {
                    previousApp = NSWorkspace.shared.frontmostApplication
                    if let pid = previousApp?.processIdentifier {
                        if let focused = AX.focusedWindow() { tracker.touch(focused) }
                        run(switcher.open(tracker.snapshot(), app: pid))
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
                    run(switcher.open(tracker.snapshot()))
                } else if switcher.mode == .strip || switcher.mode == .dropdown {
                    run(switcher.handle(flags.contains(.maskShift) ? .shiftTab : .tab))
                }
                return true
            }
            if switcher.mode != .closed && (flags.contains(.maskCommand) || (switcher.mode != .list && flags.contains(.maskAlternate))),
                let index = Self.digits.firstIndex(of: keycode)
            {
                run(switcher.handle(.jump(index)))
                return true
            }
            // Plain W must stay typeable in the search field, so the list uses ⌘W.
            if keycode == 13 && switcher.mode != .closed && (switcher.mode == .list ? flags.contains(.maskCommand) : alternate && !modifier) {
                run(switcher.handle(.closeWindow))
                return true
            }
            guard switcher.mode == .strip || switcher.mode == .dropdown else { return false }
            let key: Switcher.Key?
            switch keycode {
            case 126: key = .up
            case 125: key = .down
            case 36: key = .enter
            case 53: key = .escape
            case 24 where !modifier:
                if let id = switcher.selection?.id { run(switcher.handle(.pin(id))) }
                return true
            default: key = nil
            }
            if let key { run(switcher.handle(key)); return true }
        } else if type == .flagsChanged && !flags.contains(.maskAlternate) && (switcher.mode == .strip || switcher.mode == .dropdown) {
            run(switcher.handle(.optionUp))
            return true
        }
        return false
    }

    private func run(_ effect: Switcher.Effect) {
        switch effect {
        case .update: panel.show(switcher)
        case .focus(let window):
            stopClosePoll()
            panel.hide()
            if let element = tracker.element(window.id) {
                AX.focus(element)
                tracker.touch(element)
            } else {
                NSRunningApplication(processIdentifier: window.pid)?.activate()
            }
        case .closeWindow(let window):
            guard closePoll == nil else { break }
            guard let element = tracker.element(window.id), AX.close(element) else {
                dismissForCloseFailure(window.pid)
                break
            }
            pendingClose = window.id
            startClosePoll(checks: 10) { [weak self] in self?.checkClose(window) }
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
        case .none: break
        }
    }

    private func startClosePoll(checks: Int, _ check: @escaping @MainActor () -> Void) {
        closeChecksRemaining = checks
        closePoll = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated { check() }
        }
    }

    private func checkClose(_ window: WindowInfo) {
        guard pendingClose == window.id else { return }
        if AX.windowExists(window.id, pid: window.pid) == false {
            stopClosePoll()
            run(switcher.handle(.windowClosed(window.id)))
        } else {
            giveUpIfExhausted(window.pid)
        }
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
        pendingClose = nil
        pendingQuit = nil
    }
}
