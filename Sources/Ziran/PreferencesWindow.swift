import AppKit
import ServiceManagement

@MainActor
final class PreferencesWindow: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let tabs = NSTabViewController()
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private let iconSlider = NSSlider()
    private let iconValueLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "Sample window title · Ziran")
    private let loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let windowShortcutsCheckbox = NSButton(checkboxWithTitle: "Window resize shortcuts (listed under Window in the menu bar)", target: nil, action: nil)
    private var didCenter = false
    private let quickNavTable = NSTableView()
    private var quickNavItems: [URL] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Ziran Preferences"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        configureTabs()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(_ tab: Int = 0) {
        if tabs.tabViewItems.indices.contains(tab) { tabs.selectedTabViewItemIndex = tab }
        refreshLoginState()
        reloadQuickNav()
        if !didCenter { window?.center(); didCenter = true }
        NSApp.activate()
        showWindow(nil)
    }

    private func configureTabs() {
        tabs.tabStyle = .toolbar
        tabs.addChild(generalController())
        tabs.addChild(quickNavController())
        tabs.addChild(aboutController())
        tabs.tabViewItems[0].label = "General"
        tabs.tabViewItems[0].image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")
        tabs.tabViewItems[1].label = "Quick Nav"
        tabs.tabViewItems[1].image = NSImage(systemSymbolName: "bookmark", accessibilityDescription: "Quick Nav")
        tabs.tabViewItems[2].label = "About"
        tabs.tabViewItems[2].image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        window?.contentViewController = tabs
    }

    private func generalController() -> NSViewController {
        let controller = NSViewController()
        let title = sectionTitle("Font size")
        let fontRow = sliderRow(
            slider, value: valueLabel, range: Settings.fontSizeRange, ticks: 18, current: Settings.fontSize, action: #selector(fontSizeChanged),
            reset: #selector(resetFontSize))
        previewLabel.font = .systemFont(ofSize: Settings.fontSize)
        let caption = secondaryLabel("Scales text, rows and the panel. Applies next time the switcher opens.")
        let iconTitle = sectionTitle("Icon size")
        let iconRow = sliderRow(
            iconSlider, value: iconValueLabel, range: Settings.iconSizeRange, ticks: 15, current: Settings.iconSize, action: #selector(iconSizeChanged),
            reset: #selector(resetIconSize))
        let iconCaption = secondaryLabel("Size of app icons in the switcher strip.")
        let separator = NSBox()
        separator.boxType = .separator
        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginToggled)
        windowShortcutsCheckbox.target = self
        windowShortcutsCheckbox.action = #selector(windowShortcutsToggled)
        windowShortcutsCheckbox.state = Settings.windowShortcuts ? .on : .off
        let stack = NSStackView(views: [
            title, fontRow, previewLabel, caption, iconTitle, iconRow, iconCaption, separator, loginCheckbox, windowShortcutsCheckbox,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(20, after: caption)
        for view in [fontRow, previewLabel, caption, iconRow, iconCaption, separator] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        controller.view = NSView()
        controller.view.addSubview(stack)
        NSLayoutConstraint.activate([
            controller.view.widthAnchor.constraint(equalToConstant: 440),
            stack.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor, constant: -20),
        ])
        updateSizeLabels()
        return controller
    }

    private func quickNavController() -> NSViewController {
        let controller = NSViewController()
        let title = sectionTitle("Quick nav")
        let caption = secondaryLabel("Open items with ⌘1–9 in the switcher. ⌥− there adds the selected window.")
        quickNavTable.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item")))
        quickNavTable.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        quickNavTable.headerView = nil
        quickNavTable.rowHeight = 24
        quickNavTable.dataSource = self
        quickNavTable.delegate = self
        quickNavTable.registerForDraggedTypes([Self.quickNavRowType])
        quickNavTable.draggingDestinationFeedbackStyle = .gap
        let scroll = NSScrollView()
        scroll.documentView = quickNavTable
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: 200).isActive = true
        func button(_ title: String, _ action: Selector, key: String, modifiers: NSEvent.ModifierFlags, tip: String) -> NSButton {
            let button = NSButton(title: title, target: self, action: action)
            button.keyEquivalent = key
            button.keyEquivalentModifierMask = modifiers
            button.toolTip = tip
            button.setAccessibilityLabel(tip)
            return button
        }
        let up = String(Character(UnicodeScalar(NSUpArrowFunctionKey)!))
        let down = String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))
        let buttons = NSStackView(views: [
            button("Add File or Folder…", #selector(addQuickNavFiles), key: "o", modifiers: .command, tip: "Add file or folder (⌘O)"),
            button("Add URL…", #selector(addQuickNavURL), key: "l", modifiers: .command, tip: "Add URL (⌘L)"),
            button("Remove", #selector(removeQuickNav), key: "\u{8}", modifiers: [], tip: "Remove (⌫)"),
            button("↑", #selector(moveQuickNavUp), key: up, modifiers: .command, tip: "Move up (⌘↑)"),
            button("↓", #selector(moveQuickNavDown), key: down, modifiers: .command, tip: "Move down (⌘↓)"),
        ])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        let keys = secondaryLabel("↑↓ select · ⌘↑↓ move · ⌫ remove · ⌘O add file · ⌘L add URL")
        let stack = NSStackView(views: [title, caption, scroll, buttons, keys])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        for view in [caption, scroll] { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        stack.translatesAutoresizingMaskIntoConstraints = false
        controller.view = NSView()
        controller.view.addSubview(stack)
        NSLayoutConstraint.activate([
            controller.view.widthAnchor.constraint(equalToConstant: 440),
            stack.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor, constant: -20),
        ])
        return controller
    }

    func numberOfRows(in tableView: NSTableView) -> Int { quickNavItems.count }

    private static let quickNavRowType = NSPasteboard.PasteboardType("com.ziran.quick-nav-row")

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: Self.quickNavRowType)
        return item
    }

    func tableView(
        _ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard info.draggingSource as? NSTableView === quickNavTable else { return [] }
        if dropOperation == .on { tableView.setDropRow(row, dropOperation: .above) }
        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let value = info.draggingPasteboard.string(forType: Self.quickNavRowType), let from = Int(value), quickNavItems.indices.contains(from)
        else { return false }
        // The drop row counts the dragged item still in place, so dropping below it lands one slot earlier once removed.
        let to = row > from ? row - 1 : row
        guard to != from else { return false }
        quickNavItems.insert(quickNavItems.remove(at: from), at: to)
        Settings.quickNav = quickNavItems
        reloadQuickNav(selecting: to)
        return true
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let url = quickNavItems[row]
        let icon = NSImageView(image: url.quickNavIcon)
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let label = NSTextField(labelWithString: row < 9 ? "⌘\(row + 1)   \(url.quickNavName)" : url.quickNavName)
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let cell = NSStackView(views: [icon, label])
        cell.spacing = 8
        return cell
    }

    private func reloadQuickNav(selecting row: Int? = nil) {
        quickNavItems = Settings.quickNav
        quickNavTable.reloadData()
        if let row, quickNavItems.indices.contains(row) { quickNavTable.selectRowIndexes([row], byExtendingSelection: false) }
    }

    @objc private func addQuickNavFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        let existing = Settings.quickNav
        Settings.quickNav = existing + panel.urls.filter { !existing.contains($0) }
        reloadQuickNav()
    }

    @objc private func addQuickNavURL() {
        let alert = NSAlert()
        alert.messageText = "Add URL"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://example.com"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only web addresses: other schemes could launch arbitrary URL handlers from a single key press.
        guard let url = URL(string: text.contains("://") ? text : "https://" + text), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            url.host?.isEmpty == false
        else {
            let error = NSAlert()
            error.messageText = "Enter a web address, like https://example.com."
            error.runModal()
            return
        }
        if !Settings.quickNav.contains(url) { Settings.quickNav.append(url) }
        reloadQuickNav()
    }

    @objc private func removeQuickNav() {
        let row = quickNavTable.selectedRow
        guard quickNavItems.indices.contains(row) else { return }
        let url = quickNavItems[row]
        Settings.quickNav.removeAll { $0 == url }
        reloadQuickNav(selecting: min(row, quickNavItems.count - 2))
    }

    @objc private func moveQuickNavUp() { moveQuickNav(by: -1) }

    @objc private func moveQuickNavDown() { moveQuickNav(by: 1) }

    private func moveQuickNav(by offset: Int) {
        let row = quickNavTable.selectedRow
        guard quickNavItems.indices.contains(row), quickNavItems.indices.contains(row + offset) else { return }
        quickNavItems.swapAt(row, row + offset)
        Settings.quickNav = quickNavItems
        reloadQuickNav(selecting: row + offset)
    }

    private func aboutController() -> NSViewController {
        let controller = NSViewController()
        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 96), icon.heightAnchor.constraint(equalToConstant: 96)])
        let name = NSTextField(labelWithString: "Ziran")
        name.font = .boldSystemFont(ofSize: 22)
        let version = NSTextField(labelWithString: "Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
        let tagline = NSTextField(labelWithString: "Window switcher for macOS")
        let link = NSButton(title: "github.com/epulla/ziran", target: self, action: #selector(openProject))
        link.bezelStyle = .inline
        link.alignment = .left
        link.contentTintColor = .linkColor
        let stack = NSStackView(views: [icon, name, version, tagline, link])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        controller.view = NSView()
        controller.view.addSubview(stack)
        NSLayoutConstraint.activate([
            controller.view.widthAnchor.constraint(equalToConstant: 440),
            stack.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            stack.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor, constant: -20),
        ])
        return controller
    }

    private func sliderRow(
        _ slider: NSSlider, value: NSTextField, range: ClosedRange<Double>, ticks: Int, current: Double, action: Selector, reset: Selector
    ) -> NSView {
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.numberOfTickMarks = ticks
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        slider.target = self
        slider.action = action
        slider.doubleValue = current
        value.alignment = .right
        value.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let button = NSButton(title: "Reset", target: self, action: reset)
        button.bezelStyle = .rounded
        let row = NSStackView(views: [slider, value, button])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    private func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    private func secondaryLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        return label
    }

    @objc private func fontSizeChanged() {
        Settings.fontSize = slider.doubleValue.rounded()
        slider.doubleValue = Settings.fontSize
        updateSizeLabels()
    }

    @objc private func resetFontSize() {
        slider.doubleValue = Settings.defaultFontSize
        fontSizeChanged()
    }

    @objc private func iconSizeChanged() {
        Settings.iconSize = iconSlider.doubleValue.rounded()
        iconSlider.doubleValue = Settings.iconSize
        updateSizeLabels()
    }

    @objc private func resetIconSize() {
        iconSlider.doubleValue = Settings.defaultIconSize
        iconSizeChanged()
    }

    private func updateSizeLabels() {
        valueLabel.stringValue = "\(Int(Settings.fontSize)) pt"
        iconValueLabel.stringValue = "\(Int(Settings.iconSize)) pt"
        previewLabel.font = .systemFont(ofSize: Settings.fontSize)
    }

    private func refreshLoginState() {
        loginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func loginToggled() {
        do {
            if loginCheckbox.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSAlert(error: error).runModal()
            refreshLoginState()
        }
    }

    @objc private func windowShortcutsToggled() {
        Settings.windowShortcuts = windowShortcutsCheckbox.state == .on
    }

    @objc private func openProject() {
        NSWorkspace.shared.open(URL(string: "https://github.com/epulla/ziran")!)
    }
}
