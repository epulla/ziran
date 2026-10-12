import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var accessibilityTimer: Timer?
    private var tracker: WindowTracker?
    private var switcherTap: SwitcherTap?
    private let resizer = WindowResizer()
    private lazy var preferences = PreferencesWindow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Ziran")
        statusItem.button?.toolTip = "Ziran"
        let menu = NSMenu()
        menu.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu()
        menu.addItem(.separator())
        let preferencesItem = menu.addItem(withTitle: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        let aboutItem = menu.addItem(withTitle: "About Ziran", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(.separator())
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
        let tracker = WindowTracker(); tracker.start(); let tap = SwitcherTap(tracker: tracker, resizer: resizer)
        self.tracker = tracker; switcherTap = tap
        if !tap.start() {
            NSAlert(
                error: NSError(
                    domain: "Ziran", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ziran could not install its keyboard tap. Check Accessibility permission."]
                )
            ).runModal()
        }
    }

    private func windowMenu() -> NSMenu {
        let key = { (code: Int) in String(utf16CodeUnits: [unichar(code)], count: 1) }
        let resize: NSEvent.ModifierFlags = [.control, .option]
        let display: NSEvent.ModifierFlags = [.control, .option, .command]
        let entries: [(title: String, key: String, modifiers: NSEvent.ModifierFlags, command: WindowResizer.Command)?] = [
            ("Left Half", key(NSLeftArrowFunctionKey), resize, .layout(.leftHalf)),
            ("Right Half", key(NSRightArrowFunctionKey), resize, .layout(.rightHalf)),
            ("Top Half", key(NSUpArrowFunctionKey), resize, .layout(.topHalf)),
            ("Bottom Half", key(NSDownArrowFunctionKey), resize, .layout(.bottomHalf)),
            nil,
            ("Top Left", "u", resize, .layout(.topLeft)),
            ("Top Right", "i", resize, .layout(.topRight)),
            ("Bottom Left", "j", resize, .layout(.bottomLeft)),
            ("Bottom Right", "k", resize, .layout(.bottomRight)),
            nil,
            ("Maximize (or ⌃⌥F)", "\r", resize, .layout(.maximize)),
            ("Center", "c", resize, .layout(.center)),
            ("Restore", key(NSBackspaceCharacter), resize, .restore),
            nil,
            ("Next Display", key(NSRightArrowFunctionKey), display, .nextDisplay),
            ("Previous Display", key(NSLeftArrowFunctionKey), display, .previousDisplay),
        ]
        let menu = NSMenu()
        for entry in entries {
            guard let entry else {
                menu.addItem(.separator())
                continue
            }
            let item = menu.addItem(withTitle: entry.title, action: #selector(resizeWindow), keyEquivalent: entry.key)
            item.keyEquivalentModifierMask = entry.modifiers
            item.representedObject = entry.command
            item.target = self
        }
        return menu
    }

    @objc private func resizeWindow(_ sender: NSMenuItem) {
        if let command = sender.representedObject as? WindowResizer.Command { resizer.perform(command) }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showPreferences() {
        preferences.show(0)
    }

    @objc private func showAbout() {
        preferences.show(2)
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
