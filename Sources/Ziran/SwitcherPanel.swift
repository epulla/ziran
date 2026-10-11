import AppKit

@MainActor
final class SwitcherPanel: NSPanel, NSSearchFieldDelegate {
    private let visualEffect = PanelContentView()
    private let onKey: (Switcher.Key) -> Void
    private var search: NSTextField?
    private var currentIndex = 0
    private var icons: [pid_t: NSImage] = [:]
    private var launchObserver: NSObjectProtocol?
    private let quickNavPanel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)

    init(onKey: @escaping (Switcher.Key) -> Void) {
        self.onKey = onKey
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        visualEffect.onKey = onKey
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true
        contentView = visualEffect
        quickNavPanel.level = .popUpMenu
        quickNavPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        quickNavPanel.backgroundColor = .clear
        quickNavPanel.isOpaque = false
        quickNavPanel.hasShadow = true
        let quickNavEffect = NSVisualEffectView()
        quickNavEffect.material = .hudWindow
        quickNavEffect.blendingMode = .behindWindow
        quickNavEffect.state = .active
        quickNavEffect.wantsLayer = true
        quickNavEffect.layer?.cornerRadius = 14
        quickNavEffect.layer?.masksToBounds = true
        quickNavPanel.contentView = quickNavEffect
        // A cold icon load can take ~70 ms, so load icons up front instead of on the first open.
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular { _ = appIcon(app.processIdentifier) }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated {
                guard let pid else { return }
                _ = self?.appIcon(pid)
            }
        }
    }

    override var canBecomeKey: Bool { true }

    func show(_ s: Switcher, bookmarkHint: String?) {
        let fontSize = Settings.fontSize
        let scale = fontSize / 14
        let rowHeight = (40 * scale).rounded()
        let oldTopLeft = NSPoint(x: frame.minX, y: frame.maxY)
        let wasVisible = isVisible
        currentIndex = s.mode == .strip ? s.appIndex : s.row
        visualEffect.currentIndex = currentIndex
        let root = NSStackView()
        root.orientation = .vertical; root.alignment = .leading; root.spacing = 2
        root.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let listWidth = min((600 * scale).rounded(), (NSScreen.main?.visibleFrame.width ?? 800) - 40)
        var contentWidth = listWidth
        if s.mode == .list {
            let field = search ?? makeSearch(height: (32 * scale).rounded(), width: listWidth - 16)
            field.font = .systemFont(ofSize: fontSize); field.stringValue = s.query
            root.addArrangedSubview(field)
            root.addArrangedSubview(hint("↩ switch · ⌘1-9 jump · ⌘W close window · esc close · click pin to pin", size: 11 * scale, width: listWidth - 16))
            if s.list.isEmpty {
                root.addArrangedSubview(empty(size: rowHeight, width: listWidth - 16))
            } else {
                let start = max(0, s.row - 11)
                for (index, window) in s.list.enumerated().dropFirst(start).prefix(12) {
                    root.addArrangedSubview(
                        row(
                            window, index: index, selected: index == s.row, pinned: s.pins.contains(window.id), fontSize: fontSize, scale: scale,
                            width: listWidth - 16, height: rowHeight, mode: s.mode))
                    if index == leadingPinnedCount(s.list, pins: s.pins) - 1 && index + 1 < s.list.count {
                        let line = NSBox(); line.boxType = .separator
                        line.widthAnchor.constraint(equalToConstant: listWidth - 16).isActive = true
                        root.addArrangedSubview(line)
                    }
                }
            }
        } else {
            search = nil
            // Quick nav keeps showing the strip or dropdown it was entered from.
            let mode = s.mode == .quickNav ? s.quickNavReturn : s.mode
            let stripView = strip(s, mode: mode, fontSize: fontSize, scale: scale)
            let stripWidth = stripView.fittingSize.width
            contentWidth = mode == .dropdown ? max(listWidth, stripWidth) : stripWidth
            stripView.widthAnchor.constraint(equalToConstant: contentWidth - 16).isActive = true
            root.addArrangedSubview(stripView)
            if mode == .dropdown {
                for (index, window) in s.dropdown.enumerated() {
                    root.addArrangedSubview(
                        row(
                            window, index: index, selected: index == s.row, pinned: s.pins.contains(window.id), fontSize: fontSize, scale: scale,
                            width: contentWidth - 16, height: rowHeight, mode: mode))
                    if index == leadingPinnedCount(s.dropdown, pins: s.pins) - 1 && index + 1 < s.dropdown.count {
                        let line = NSBox(); line.boxType = .separator
                        line.widthAnchor.constraint(equalToConstant: contentWidth - 16).isActive = true
                        root.addArrangedSubview(line)
                    }
                }
                root.addArrangedSubview(hint("= pin · W close window · ↑↓ move · 1-9 jump · release ⌥ to switch", size: 11 * scale, width: contentWidth - 16))
            }
        }
        visualEffect.subviews.forEach { $0.removeFromSuperview() }
        visualEffect.addSubview(root)
        root.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            root.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            root.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            root.widthAnchor.constraint(equalToConstant: contentWidth),
        ])
        setContentSize(root.fittingSize)
        if wasVisible {
            setFrameTopLeftPoint(oldTopLeft)
        } else if let screen = NSScreen.main {
            let area = screen.visibleFrame
            setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: area.midY - frame.height / 2))
        }
        orderFrontRegardless()
        showQuickNav(s, bookmarkHint: bookmarkHint, fontSize: fontSize, scale: scale, rowHeight: rowHeight)
        if s.mode == .list {
            makeKey()
            search?.becomeFirstResponder()
            search?.currentEditor()?.selectedRange = NSRange(location: search?.stringValue.count ?? 0, length: 0)
        }
    }

    func hide() {
        orderOut(nil)
        quickNavPanel.orderOut(nil)
    }

    private func showQuickNav(_ s: Switcher, bookmarkHint: String?, fontSize: CGFloat, scale: CGFloat, rowHeight: CGFloat) {
        guard s.mode != .list, let effect = quickNavPanel.contentView else {
            quickNavPanel.orderOut(nil)
            return
        }
        let box = quickNavBox(s, bookmarkHint: bookmarkHint, fontSize: fontSize, scale: scale, rowHeight: rowHeight)
        effect.subviews.forEach { $0.removeFromSuperview() }
        effect.addSubview(box)
        box.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: effect.leadingAnchor), box.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            box.topAnchor.constraint(equalTo: effect.topAnchor), box.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        quickNavPanel.setContentSize(box.fittingSize)
        let gap: CGFloat = 12
        let width = quickNavPanel.frame.width
        let area = (screen ?? NSScreen.main)?.visibleFrame ?? .infinite
        let x = frame.maxX + gap + width <= area.maxX ? frame.maxX + gap : frame.minX - gap - width
        quickNavPanel.setFrameTopLeftPoint(NSPoint(x: x, y: frame.maxY))
        quickNavPanel.orderFrontRegardless()
    }

    // Loading an app icon costs ~5 ms and every key press re-renders every tile.
    private func appIcon(_ pid: pid_t) -> NSImage {
        if let cached = icons[pid] { return cached }
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon else { return NSImage() }
        icons[pid] = icon
        return icon
    }

    private func makeSearch(height: CGFloat, width: CGFloat) -> NSTextField {
        let field = NSSearchField()
        field.placeholderString = "Type to filter"
        field.delegate = self
        field.heightAnchor.constraint(equalToConstant: height).isActive = true
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        search = field
        return field
    }

    private func strip(_ s: Switcher, mode: Switcher.Mode, fontSize: CGFloat, scale: CGFloat) -> NSView {
        let box = NSStackView()
        box.orientation = .vertical
        box.alignment = .centerX
        let icons = NSStackView()
        icons.spacing = (8 * scale).rounded()
        // Without this the stack can stretch to the dropdown width on re-render and pin the icon left.
        icons.setHuggingPriority(.required, for: .horizontal)
        let size = Settings.iconSize
        for (index, pid) in s.apps.enumerated() {
            let tile: NSView = mode == .strip ? RowView(index: index, onKey: onKey) : NSView()
            tile.wantsLayer = true
            tile.layer?.cornerRadius = size * 0.16
            tile.layer?.backgroundColor = index == s.appIndex ? NSColor.labelColor.withAlphaComponent(0.18).cgColor : NSColor.clear.cgColor
            let icon = NSImageView(image: appIcon(pid))
            icon.imageScaling = .scaleProportionallyUpOrDown; tile.addSubview(icon)
            icon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tile.widthAnchor.constraint(equalToConstant: size), tile.heightAnchor.constraint(equalToConstant: size),
                icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor), icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: size * 0.78), icon.heightAnchor.constraint(equalToConstant: size * 0.78),
            ])
            if mode == .strip, let badge = badge(index, size: 11 * scale, selected: false) {
                tile.addSubview(badge)
                NSLayoutConstraint.activate([
                    badge.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -(size * 0.08).rounded()),
                    badge.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -(size * 0.08).rounded()),
                ])
            }
            icons.addArrangedSubview(tile)
        }
        box.addArrangedSubview(icons)
        let app = s.apps.indices.contains(s.appIndex) ? NSRunningApplication(processIdentifier: s.apps[s.appIndex])?.localizedName ?? "" : ""
        let label = NSTextField(labelWithString: app)
        label.font = .systemFont(ofSize: fontSize, weight: .medium); label.lineBreakMode = .byTruncatingMiddle; label.alignment = .center
        label.widthAnchor.constraint(equalToConstant: max(size, icons.fittingSize.width)).isActive = true
        box.addArrangedSubview(label)
        if mode == .strip {
            let stripHint = hint("↑ search   ↓ windows   W close all   Q quit", size: 11 * scale)
            stripHint.setContentCompressionResistancePriority(.required, for: .horizontal)
            box.addArrangedSubview(stripHint)
        }
        return box
    }

    private func row(
        _ window: WindowInfo, index: Int, selected: Bool, pinned: Bool, fontSize: CGFloat, scale: CGFloat, width: CGFloat, height: CGFloat, mode: Switcher.Mode
    )
        -> NSView
    {
        let row = RowView(index: index, onKey: onKey)
        row.wantsLayer = true
        row.layer?.cornerRadius = 8 * scale
        row.layer?.backgroundColor = selected ? NSColor.selectedContentBackgroundColor.cgColor : NSColor.clear.cgColor
        let icon = NSImageView(image: appIcon(window.pid))
        icon.imageScaling = .scaleProportionallyUpOrDown
        let appName = window.appName
        let title = window.title.isEmpty || window.title == appName ? appName : window.title + "  —  " + appName
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: fontSize, weight: selected ? .semibold : .regular); label.textColor = selected ? .white : .labelColor
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let pin = PinButton(pinned: pinned, selected: selected)
        pin.onKey = { [onKey] in onKey(.pin(window.id)) }
        row.addSubview(icon); row.addSubview(label); row.addSubview(pin)
        for view in [icon, label, pin] { view.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalToConstant: width), row.heightAnchor.constraint(equalToConstant: height),
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8), icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28 * scale), icon.heightAnchor.constraint(equalToConstant: 28 * scale),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10), label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            pin.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8), pin.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            pin.widthAnchor.constraint(equalToConstant: 28 * scale), pin.heightAnchor.constraint(equalToConstant: 28 * scale),
        ])
        if let badge = badge(index, size: 11 * scale, selected: selected, prefix: mode == .list ? "⌘" : "") {
            row.addSubview(badge)
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(equalTo: badge.leadingAnchor, constant: -8),
                badge.trailingAnchor.constraint(equalTo: pin.leadingAnchor, constant: -6), badge.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])
        } else {
            label.trailingAnchor.constraint(equalTo: pin.leadingAnchor, constant: -8).isActive = true
        }
        return row
    }

    private func quickNavBox(_ s: Switcher, bookmarkHint: String?, fontSize: CGFloat, scale: CGFloat, rowHeight: CGFloat) -> NSView {
        let width = (260 * scale).rounded()
        let box = NSStackView()
        box.orientation = .vertical; box.alignment = .leading; box.spacing = 2
        box.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let title = NSTextField(labelWithString: "Quick nav")
        title.font = .systemFont(ofSize: 11 * scale, weight: .semibold)
        title.textColor = .secondaryLabelColor
        box.addArrangedSubview(title)
        for (index, url) in s.quickNav.enumerated() {
            let selected = s.mode == .quickNav && index == s.quickNavRow
            let row = NSView()
            row.wantsLayer = true
            row.layer?.cornerRadius = 8 * scale
            row.layer?.backgroundColor = selected ? NSColor.selectedContentBackgroundColor.cgColor : NSColor.clear.cgColor
            let image = url.isFileURL ? NSWorkspace.shared.icon(forFile: url.path) : NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
            let icon = NSImageView(image: image ?? NSImage())
            icon.imageScaling = .scaleProportionallyUpOrDown
            let label = NSTextField(labelWithString: url.quickNavName)
            label.font = .systemFont(ofSize: fontSize, weight: selected ? .semibold : .regular); label.textColor = selected ? .white : .labelColor
            label.lineBreakMode = .byTruncatingMiddle
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            row.addSubview(icon); row.addSubview(label)
            for view in [icon, label] { view.translatesAutoresizingMaskIntoConstraints = false }
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalToConstant: width - 16), row.heightAnchor.constraint(equalToConstant: rowHeight),
                icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8), icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 24 * scale), icon.heightAnchor.constraint(equalToConstant: 24 * scale),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8), label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])
            if let badge = badge(index, size: 11 * scale, selected: selected, prefix: "⇧") {
                row.addSubview(badge)
                NSLayoutConstraint.activate([
                    label.trailingAnchor.constraint(lessThanOrEqualTo: badge.leadingAnchor, constant: -8),
                    badge.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8), badge.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                ])
            } else {
                label.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -8).isActive = true
            }
            box.addArrangedSubview(row)
        }
        let footer =
            s.mode == .quickNav
            ? ["↑↓ move · ↩ open · ⌥− remove · ← back"] : [bookmarkHint, s.quickNav.isEmpty ? nil : "→ select · ⌥⇧1-9 open"].compactMap { $0 }
        for line in footer { box.addArrangedSubview(hint(line, size: 11 * scale, width: width - 16)) }
        return box
    }

    private func badge(_ index: Int, size: CGFloat, selected: Bool, prefix: String = "") -> NSView? {
        guard index < 9 else { return nil }
        let label = NSTextField(labelWithString: "\(prefix)\(index + 1)")
        label.font = .monospacedDigitSystemFont(ofSize: size, weight: .medium)
        label.textColor = selected ? .white : .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func hint(_ text: String, size: CGFloat, width: CGFloat? = nil) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        if let width {
            label.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        return label
    }

    private func empty(size: CGFloat, width: CGFloat) -> NSView {
        let label = NSTextField(labelWithString: "No matches")
        label.font = .systemFont(ofSize: size / 1.5)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.widthAnchor.constraint(equalToConstant: width).isActive = true
        label.heightAnchor.constraint(equalToConstant: size).isActive = true
        return label
    }

    private func leadingPinnedCount(_ windows: [WindowInfo], pins: [CGWindowID]) -> Int {
        return windows.prefix { pins.contains($0.id) }.count
    }

    func controlTextDidChange(_ obj: Notification) { if let field = obj.object as? NSTextField { onKey(.query(field.stringValue)) } }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let key: Switcher.Key?
        switch commandSelector {
        case #selector(moveUp): key = .up
        case #selector(moveDown): key = .down
        case #selector(insertNewline): key = .enter
        case #selector(cancelOperation): key = .escape
        default: key = nil
        }
        if let key { onKey(key); return true }
        return false
    }
}

@MainActor
private final class PanelContentView: NSVisualEffectView {
    var onKey: ((Switcher.Key) -> Void)?
    var currentIndex = 0
    var scrollAccumulator: CGFloat = 0

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        if let row = hitTest(convert(event.locationInWindow, from: nil))?.nearestRow, row.index != currentIndex {
            onKey?(.select(row.index))
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let step: CGFloat = event.hasPreciseScrollingDeltas ? 20 : 1
        scrollAccumulator += event.scrollingDeltaY
        while scrollAccumulator <= -step { scrollAccumulator += step; onKey?(.select(currentIndex + 1)) }
        while scrollAccumulator >= step { scrollAccumulator -= step; onKey?(.select(currentIndex - 1)) }
    }
}

@MainActor
private final class RowView: NSView {
    let index: Int
    let onKey: (Switcher.Key) -> Void

    init(index: Int, onKey: @escaping (Switcher.Key) -> Void) {
        self.index = index
        self.onKey = onKey
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { onKey(.select(index)); onKey(.enter) }
}

@MainActor
private final class PinButton: NSImageView {
    var onKey: (() -> Void)?

    init(pinned: Bool, selected: Bool) {
        super.init(frame: .zero)
        setPinned(pinned, selected: selected)
        imageScaling = .scaleProportionallyDown
    }

    required init?(coder: NSCoder) { fatalError() }

    func setPinned(_ pinned: Bool, selected: Bool) {
        image = NSImage(systemSymbolName: pinned ? "pin.fill" : "pin", accessibilityDescription: nil)
        contentTintColor = pinned ? (selected ? .white : .systemOrange) : (selected ? .white : NSColor.secondaryLabelColor.withAlphaComponent(0.5))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { onKey?() }
}

private extension NSView {
    var nearestRow: RowView? {
        var view: NSView? = self
        while let current = view {
            if let row = current as? RowView { return row }
            view = current.superview
        }
        return nil
    }
}

extension URL {
    var quickNavName: String {
        guard isFileURL else {
            let name = (host ?? "") + path
            return name.isEmpty ? absoluteString : name
        }
        let name = FileManager.default.displayName(atPath: path)
        return hasDirectoryPath && pathExtension != "app" ? "\(name) (folder)" : name
    }
}
