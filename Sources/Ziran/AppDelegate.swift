import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var accessibilityTimer: Timer?
    private var tracker: WindowTracker?
    private var switcherTap: SwitcherTap?
    private var hotKeyMonitor: HotKeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Ziran")
        statusItem.button?.toolTip = "Ziran"
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Ziran", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            start()
        } else {
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                MainActor.assumeIsolated {
                    self?.accessibilityTimer = nil
                    self?.start()
                }
            }
        }
    }

    private func start() {
        let tracker = WindowTracker(); tracker.start(); let tap = SwitcherTap(tracker: tracker)
        self.tracker = tracker; switcherTap = tap
        if !tap.start() { NSAlert(error: NSError(domain: "Ziran", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ziran could not install its keyboard tap. Check Accessibility permission."])).runModal() }
        let monitor = HotKeyMonitor(); hotKeyMonitor = monitor
        let failed = SnapAction.allCases.filter { action in
            !monitor.register(keyCode: action.keyCode, modifiers: action.modifiers) { [weak self] in self?.snap(action) }
        }
        if !failed.isEmpty {
            let alert = NSAlert(); alert.messageText = "Some snap shortcuts are taken by another app (quit Rectangle?)"
            alert.informativeText = failed.map(String.init(describing:)).joined(separator: ", "); alert.runModal()
        }
    }

    private func snap(_ action: SnapAction) {
        guard let window = AX.focusedWindow(), let axFrame = AX.frame(window), let primary = NSScreen.screens.first else { return }
        let primaryMaxY = primary.frame.maxY
        let current = AX.flip(axFrame, primaryMaxY: primaryMaxY)
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        let area = { (screen: NSScreen) in screen.frame.intersection(current).width * screen.frame.intersection(current).height }
        guard let screen = screens.max(by: { area($0) < area($1) }) else { return }
        let new: CGRect
        if action == .nextDisplay || action == .previousDisplay {
            guard screens.count > 1, let index = screens.firstIndex(of: screen) else { return }
            let target = screens[(index + (action == .nextDisplay ? 1 : -1) + screens.count) % screens.count]
            new = SnapAction.moved(current, from: screen.visibleFrame, to: target.visibleFrame)
        } else {
            new = action.frame(visible: screen.visibleFrame, current: current)
        }
        AX.setFrame(window, AX.flip(new, primaryMaxY: primaryMaxY))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@main
struct ZiranApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
