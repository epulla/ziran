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
        statusItem.button?.image = Self.menuBarIcon() ?? NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Ziran")
        statusItem.button?.setAccessibilityLabel("Ziran")
        statusItem.button?.toolTip = "Ziran"
        let menu = NSMenu()
        let windowItem = menu.addItem(withTitle: "Window", action: nil, keyEquivalent: "")
        windowItem.submenu = windowMenu()
        menu.addItem(.separator())
        let preferencesItem = menu.addItem(withTitle: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        let aboutItem = menu.addItem(withTitle: "About Ziran", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: "Quit Ziran", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        for (item, symbol) in [(windowItem, "macwindow"), (preferencesItem, "gearshape"), (aboutItem, "info.circle"), (quitItem, "power")] {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        statusItem.menu = menu
        Settings.applyLaunchAtLoginDefault()

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

    // The fox ships inside the .app built by scripts/bundle.sh; `make run` has no bundle resources and keeps the SF Symbol.
    static func menuBarIcon(in bundle: Bundle = .main) -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        for name in ["ZiranMenuBarTemplate", "ZiranMenuBarTemplate@2x"] {
            guard let url = bundle.url(forResource: name, withExtension: "png"), let representation = NSImageRep(contentsOf: url) else { continue }
            representation.size = size
            image.addRepresentation(representation)
        }
        guard !image.representations.isEmpty else { return nil }
        image.isTemplate = true
        image.accessibilityDescription = "Ziran"
        return image
    }

    private func windowMenu() -> NSMenu {
        let key = { (code: Int) in String(utf16CodeUnits: [unichar(code)], count: 1) }
        let resize: NSEvent.ModifierFlags = [.control, .option]
        let display: NSEvent.ModifierFlags = [.control, .option, .command]
        let entries: [(title: String, key: String, modifiers: NSEvent.ModifierFlags, command: WindowResizer.Command, symbol: String)?] = [
            ("Left Half", key(NSLeftArrowFunctionKey), resize, .layout(.leftHalf), "rectangle.lefthalf.filled"),
            ("Right Half", key(NSRightArrowFunctionKey), resize, .layout(.rightHalf), "rectangle.righthalf.filled"),
            ("Top Half", key(NSUpArrowFunctionKey), resize, .layout(.topHalf), "rectangle.tophalf.filled"),
            ("Bottom Half", key(NSDownArrowFunctionKey), resize, .layout(.bottomHalf), "rectangle.bottomhalf.filled"),
            nil,
            ("Top Left", "u", resize, .layout(.topLeft), "rectangle.inset.topleft.filled"),
            ("Top Right", "i", resize, .layout(.topRight), "rectangle.inset.topright.filled"),
            ("Bottom Left", "j", resize, .layout(.bottomLeft), "rectangle.inset.bottomleft.filled"),
            ("Bottom Right", "k", resize, .layout(.bottomRight), "rectangle.inset.bottomright.filled"),
            nil,
            ("Maximize (or ⌃⌥F)", "\r", resize, .layout(.maximize), "rectangle.inset.filled"),
            ("Center", "c", resize, .layout(.center), "rectangle.center.inset.filled"),
            ("Restore", key(NSBackspaceCharacter), resize, .restore, "arrow.uturn.backward"),
            nil,
            ("Next Display", key(NSRightArrowFunctionKey), display, .nextDisplay, "arrow.right.square"),
            ("Previous Display", key(NSLeftArrowFunctionKey), display, .previousDisplay, "arrow.left.square"),
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
            item.image = NSImage(systemSymbolName: entry.symbol, accessibilityDescription: nil)
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
