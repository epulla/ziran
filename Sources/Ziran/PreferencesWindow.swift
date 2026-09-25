import AppKit
import ServiceManagement

@MainActor
final class PreferencesWindow: NSWindowController {
    private let tabs = NSTabViewController()
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private let iconSlider = NSSlider()
    private let iconValueLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "Sample window title  —  Ziran")
    private let loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private var didCenter = false

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
        let stack = NSStackView(views: [title, fontRow, previewLabel, caption, iconTitle, iconRow, iconCaption, separator, loginCheckbox])
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

    @objc private func openProject() {
        NSWorkspace.shared.open(URL(string: "https://github.com/epulla/ziran")!)
    }
}
