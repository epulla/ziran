import AppKit
import ServiceManagement

@MainActor
final class PreferencesWindow: NSWindowController {
    private let tabs = NSTabViewController()
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "Sample window title  —  Ziran")
    private let loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private var didCenter = false

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
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
        if !didCenter { window?.center(); didCenter = true }
        NSApp.activate()
        showWindow(nil)
    }

    private func configureTabs() {
        tabs.tabStyle = .toolbar
        tabs.addChild(generalController())
        tabs.addChild(aboutController())
        tabs.tabViewItems[0].label = "General"
        tabs.tabViewItems[0].image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")
        tabs.tabViewItems[1].label = "About"
        tabs.tabViewItems[1].image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        window?.contentViewController = tabs
    }

    private func generalController() -> NSViewController {
        let controller = NSViewController()
        let title = NSTextField(labelWithString: "Font size")
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        slider.minValue = Settings.fontSizeRange.lowerBound
        slider.maxValue = Settings.fontSizeRange.upperBound
        slider.numberOfTickMarks = 18
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(fontSizeChanged)
        slider.doubleValue = Settings.fontSize
        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 42).isActive = true
        previewLabel.font = .systemFont(ofSize: Settings.fontSize)
        let reset = NSButton(title: "Reset", target: self, action: #selector(resetFontSize))
        reset.bezelStyle = .rounded
        let sliderRow = NSStackView(views: [slider, valueLabel, reset])
        sliderRow.orientation = .horizontal
        sliderRow.spacing = 8
        let caption = secondaryLabel("Scales rows, icons and the panel. Applies next time the switcher opens.")
        let separator = NSBox()
        separator.boxType = .separator
        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginToggled)
        let stack = NSStackView(views: [title, sliderRow, previewLabel, caption, separator, loginCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        sliderRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        previewLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        caption.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        controller.view = NSView()
        controller.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: 20)
        ])
        updateFontSizeLabels()
        return controller
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
        let attribution = secondaryLabel("UI based on AltTab by Alex Le (MIT)")
        let stack = NSStackView(views: [icon, name, version, tagline, link, attribution])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        controller.view = NSView()
        controller.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            stack.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: 20)
        ])
        return controller
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
        updateFontSizeLabels()
    }

    @objc private func resetFontSize() {
        slider.doubleValue = Settings.defaultFontSize
        fontSizeChanged()
    }

    private func updateFontSizeLabels() {
        valueLabel.stringValue = "\(Int(Settings.fontSize)) pt"
        previewLabel.font = .systemFont(ofSize: Settings.fontSize)
    }

    private func refreshLoginState() {
        loginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func loginToggled() {
        do {
            if loginCheckbox.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSAlert(error: error).runModal()
            refreshLoginState()
        }
    }

    @objc private func openProject() {
        NSWorkspace.shared.open(URL(string: "https://github.com/epulla/ziran")!)
    }
}
