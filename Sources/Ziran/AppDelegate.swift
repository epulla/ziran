import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var accessibilityTimer: Timer?
    private var tracker: WindowTracker?
    private var switcherTap: SwitcherTap?
    private var hotKeyMonitor: HotKeyMonitor?
    private var layouts: [Layout] = []
    private var layoutsLoadFailed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Ziran")
        statusItem.button?.toolTip = "Ziran"
        rebuildMenu()

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
        do { layouts = try Layouts.load() } catch {
            layoutsLoadFailed = true
            let alert = NSAlert(); alert.messageText = "Could not read layouts.json"; alert.informativeText = "\(error). Saving is disabled so the file is not overwritten."; alert.runModal()
        }
        let tracker = WindowTracker(); tracker.start(); let tap = SwitcherTap(tracker: tracker)
        self.tracker = tracker; switcherTap = tap
        tap.layoutsMenu = { [weak self] in self?.layoutMenu() ?? NSMenu() }
        if !tap.start() { NSAlert(error: NSError(domain: "Ziran", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ziran could not install its keyboard tap. Check Accessibility permission."])).runModal() }
        let monitor = HotKeyMonitor(); hotKeyMonitor = monitor
        var failed = SnapAction.allCases.compactMap { action -> String? in
            !monitor.register(keyCode: action.keyCode, modifiers: action.modifiers) { [weak self] in self?.snap(action) }
                ? String(describing: action) : nil
        }
        let keys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        for i in 0..<9 where !monitor.register(keyCode: keys[i], modifiers: Int(controlKey | optionKey | shiftKey), action: { [weak self] in self?.restore(i) }) { failed.append("layout \(i + 1)") }
        if !failed.isEmpty {
            let alert = NSAlert(); alert.messageText = "Some snap shortcuts are taken by another app (quit Rectangle?)"
            alert.informativeText = failed.joined(separator: ", "); alert.runModal()
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = statusItem.menu ?? NSMenu(); menu.removeAllItems()
        let save = menu.addItem(withTitle: "Save Layout…", action: #selector(saveLayout), keyEquivalent: ""); save.target = self; save.isEnabled = !layoutsLoadFailed
        let layoutsItem = menu.addItem(withTitle: "Layouts", action: nil, keyEquivalent: "")
        let submenu = NSMenu(); layoutsItem.submenu = submenu
        for (index, layout) in layouts.enumerated() {
            let item = NSMenuItem(title: layout.name + (index < 9 ? "  (⌃⌥⇧\(index + 1))" : ""), action: nil, keyEquivalent: "")
            let actions = NSMenu(); item.submenu = actions
            let restore = actions.addItem(withTitle: "Restore", action: #selector(restoreMenuItem), keyEquivalent: ""); restore.target = self; restore.representedObject = index
            let delete = actions.addItem(withTitle: "Delete", action: #selector(deleteLayout), keyEquivalent: ""); delete.target = self; delete.representedObject = index
            submenu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Ziran", action: #selector(quit), keyEquivalent: "q"); quit.target = self
        statusItem.menu = menu
    }

    private func layoutMenu() -> NSMenu {
        let menu = NSMenu()
        for (index, layout) in layouts.enumerated() { let item = menu.addItem(withTitle: layout.name, action: #selector(restoreMenuItem), keyEquivalent: ""); item.target = self; item.representedObject = index }
        return menu
    }

    @objc private func saveLayout() {
        guard let tracker else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "Save Layout"; alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: "Layout \(layouts.count + 1)"); field.frame = NSRect(x: 0, y: 0, width: 240, height: 24); alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines); guard !name.isEmpty else { return }
        let layout = Layouts.capture(name: name, tracker: tracker)
        if let index = layouts.firstIndex(where: { $0.name == name }) { layouts[index] = layout } else { layouts.append(layout) }
        do { try Layouts.save(layouts) } catch { NSAlert(error: error).runModal() }
        rebuildMenu()
    }

    @objc private func restoreMenuItem(_ sender: NSMenuItem) { if let index = sender.representedObject as? Int { restore(index) } }
    @objc private func deleteLayout(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, layouts.indices.contains(index) else { return }
        layouts.remove(at: index); do { try Layouts.save(layouts) } catch { NSAlert(error: error).runModal() }; rebuildMenu()
    }
    private func restore(_ index: Int) { guard layouts.indices.contains(index), let tracker else { return }; Layouts.restore(layouts[index], tracker: tracker) }

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
