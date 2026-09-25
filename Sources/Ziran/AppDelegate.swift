import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var accessibilityTimer: Timer?
    private var tracker: WindowTracker?
    private var switcherTap: SwitcherTap?
    private lazy var preferences = PreferencesWindow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Ziran")
        statusItem.button?.toolTip = "Ziran"
        let menu = NSMenu()
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
        let tracker = WindowTracker(); tracker.start(); let tap = SwitcherTap(tracker: tracker)
        self.tracker = tracker; switcherTap = tap
        if !tap.start() {
            NSAlert(
                error: NSError(
                    domain: "Ziran", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ziran could not install its keyboard tap. Check Accessibility permission."]
                )
            ).runModal()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showPreferences() {
        preferences.show(0)
    }

    @objc private func showAbout() {
        preferences.show(1)
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
