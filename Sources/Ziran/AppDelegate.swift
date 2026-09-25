import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var accessibilityTimer: Timer?

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
                self?.accessibilityTimer = nil
                self?.start()
            }
        }
    }

    private func start() {}

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
