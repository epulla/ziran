import AppKit

@MainActor
final class SwitcherPanel: NSPanel, NSSearchFieldDelegate {
    private let visualEffect = PanelContentView()
    private let onKey: (Switcher.Key) -> Void
    private var search: NSTextField?
    private var currentIndex = 0
    private var icons: [pid_t: NSImage] = [:]
    private var bundleIcons: [String: NSImage] = [:]
    private var templatesScroll: NSScrollView?
    private var launchObserver: NSObjectProtocol?
    // One padding for every panel edge, row inset, and gap between sections, so all views line up.
    private static let gap: CGFloat = 8
    private static let quickNavSpacing: CGFloat = 12
    private static let quickNavBaseWidth: CGFloat = 260
    private let quickNavPanel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private let templatesPanel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)

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
        for side in [quickNavPanel, templatesPanel] {
            side.level = .popUpMenu
            side.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            side.backgroundColor = .clear
            side.isOpaque = false
            side.hasShadow = true
            let effect = NSVisualEffectView()
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 14
            effect.layer?.masksToBounds = true
            side.contentView = effect
        }
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
        root.edgeInsets = NSEdgeInsets(top: Self.gap, left: Self.gap, bottom: Self.gap, right: Self.gap)
        let area = (wasVisible ? screen : nil)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let quickNavWidth = (Self.quickNavBaseWidth * scale).rounded()
        let listWidth = min((600 * scale).rounded(), area.width - 40)
        var contentWidth = listWidth
        if s.mode == .list {
            let field = search ?? makeSearch(height: (32 * scale).rounded(), width: listWidth - 2 * Self.gap)
            field.font = .systemFont(ofSize: fontSize); field.stringValue = s.query
            root.addArrangedSubview(field)
            root.setCustomSpacing(Self.gap, after: field)
            for line in ["↑↓ move · ↩ switch · esc close", "⌘= pin · ⌘W close window"] {
                let searchHint = hint(line, size: 11 * scale, width: listWidth - 2 * Self.gap)
                searchHint.alignment = .center
                root.addArrangedSubview(searchHint)
                root.setCustomSpacing(Self.gap, after: searchHint)
            }
            if s.list.isEmpty {
                root.addArrangedSubview(empty(size: rowHeight, width: listWidth - 2 * Self.gap))
            } else {
                let start = max(0, s.row - 11)
                for (index, window) in s.list.enumerated().dropFirst(start).prefix(12) {
                    root.addArrangedSubview(
                        row(
                            window, index: index, selected: index == s.row, pinned: s.pins.contains(window.id), fontSize: fontSize, scale: scale,
                            width: listWidth - 2 * Self.gap, height: rowHeight, mode: s.mode))
                    if index == leadingPinnedCount(s.list, pins: s.pins) - 1 && index + 1 < s.list.count {
                        let line = NSBox(); line.boxType = .separator
                        line.widthAnchor.constraint(equalToConstant: listWidth - 2 * Self.gap).isActive = true
                        root.addArrangedSubview(line)
                    }
                }
            }
        } else {
            search = nil
            // Side boxes keep showing the strip or dropdown they were entered from.
            let mode = s.mode == .quickNav ? s.quickNavReturn : s.mode == .templates ? s.templatesReturn : s.mode
            let stripView = strip(
                s, mode: mode, fontSize: fontSize, scale: scale, maxWidth: listWidth - 2 * Self.gap,
                iconsWidth: area.width - 2 * (Self.quickNavSpacing + quickNavWidth) - 2 * Self.gap)
            let stripWidth = stripView.fittingSize.width
            contentWidth = max(mode == .dropdown ? listWidth : 0, stripWidth + 2 * Self.gap)
            stripView.widthAnchor.constraint(equalToConstant: contentWidth - 2 * Self.gap).isActive = true
            root.addArrangedSubview(stripView)
            root.setCustomSpacing(Self.gap, after: stripView)
            if mode == .dropdown {
                for (index, window) in s.dropdown.enumerated() {
                    root.addArrangedSubview(
                        row(
                            window, index: index, selected: index == s.row, pinned: s.pins.contains(window.id), fontSize: fontSize, scale: scale,
                            width: contentWidth - 2 * Self.gap, height: rowHeight, mode: mode))
                    if index == leadingPinnedCount(s.dropdown, pins: s.pins) - 1 && index + 1 < s.dropdown.count {
                        let line = NSBox(); line.boxType = .separator
                        line.widthAnchor.constraint(equalToConstant: contentWidth - 2 * Self.gap).isActive = true
                        root.addArrangedSubview(line)
                    }
                }
                if let last = root.arrangedSubviews.last { root.setCustomSpacing(Self.gap, after: last) }
                for line in hintLines(s.mode) {
                    let label = hint(line, size: 11 * scale, width: contentWidth - 2 * Self.gap)
                    label.alignment = .center
                    root.addArrangedSubview(label)
                }
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
        let x = Layout.panelX(
            current: wasVisible ? oldTopLeft.x : nil, width: frame.width, sideWidth: quickNavWidth, spacing: Self.quickNavSpacing, area: area)
        if wasVisible {
            setFrameTopLeftPoint(NSPoint(x: x, y: oldTopLeft.y))
        } else {
            setFrameOrigin(NSPoint(x: x, y: area.midY - frame.height / 2))
        }
        orderFrontRegardless()
        if s.mode == .list {
            quickNavPanel.orderOut(nil)
            templatesPanel.orderOut(nil)
        } else {
            let quickNavBox = quickNavBox(s, bookmarkHint: bookmarkHint, fontSize: fontSize, scale: scale, rowHeight: rowHeight)
            showSide(quickNavPanel, box: quickNavBox, x: frame.maxX + Self.quickNavSpacing)
            let templates = templatesBox(s, fontSize: fontSize, scale: scale)
            let size = templates.box.fittingSize
            // Each render rebuilds the scroll view, so carry the scroll position over.
            let offset = templatesScroll?.contentView.bounds.origin ?? .zero
            let scroll = NSScrollView()
            scroll.drawsBackground = false
            scroll.hasVerticalScroller = true
            scroll.autohidesScrollers = true
            let document = FlippedView()
            document.addSubview(templates.box)
            scroll.documentView = document
            for view in [templates.box, document] { view.translatesAutoresizingMaskIntoConstraints = false }
            NSLayoutConstraint.activate([
                templates.box.leadingAnchor.constraint(equalTo: document.leadingAnchor),
                templates.box.trailingAnchor.constraint(equalTo: document.trailingAnchor),
                templates.box.topAnchor.constraint(equalTo: document.topAnchor),
                templates.box.bottomAnchor.constraint(equalTo: document.bottomAnchor),
                document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
                document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
                document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
                scroll.widthAnchor.constraint(equalToConstant: size.width),
                scroll.heightAnchor.constraint(equalToConstant: min(size.height, frame.maxY - area.minY - 2 * Self.gap)),
            ])
            templatesScroll = scroll
            showSide(templatesPanel, box: scroll, x: frame.minX - Self.quickNavSpacing - size.width - 2 * Self.gap)
            scroll.layoutSubtreeIfNeeded()
            document.scroll(offset)
            if let selected = templates.selected { selected.scrollToVisible(selected.bounds) }
        }
        if s.mode == .list {
            makeKey()
            search?.becomeFirstResponder()
            search?.currentEditor()?.selectedRange = NSRange(location: search?.stringValue.count ?? 0, length: 0)
        }
    }

    func hide() {
        orderOut(nil)
        quickNavPanel.orderOut(nil)
        templatesPanel.orderOut(nil)
    }

    private func showSide(_ side: NSPanel, box: NSView, x: CGFloat) {
        guard let effect = side.contentView else { return }
        effect.subviews.forEach { $0.removeFromSuperview() }
        effect.addSubview(box)
        box.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: Self.gap),
            box.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -Self.gap),
            box.topAnchor.constraint(equalTo: effect.topAnchor, constant: Self.gap),
            box.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -Self.gap),
        ])
        side.setContentSize(effect.fittingSize)
        side.setFrameTopLeftPoint(NSPoint(x: x, y: frame.maxY))
        side.orderFrontRegardless()
    }

    // Loading an app icon costs ~5 ms and every key press re-renders every tile.
    private func appIcon(_ pid: pid_t) -> NSImage {
        if let cached = icons[pid] { return cached }
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon else { return NSImage() }
        icons[pid] = icon
        return icon
    }

    private func bundleIcon(_ bundleID: String) -> NSImage {
        if let cached = bundleIcons[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return NSImage() }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        bundleIcons[bundleID] = icon
        return icon
    }

    private func iconView(_ image: NSImage, size: CGFloat) -> NSImageView {
        let icon = NSImageView(image: image)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: size).isActive = true
        icon.heightAnchor.constraint(equalToConstant: size).isActive = true
        return icon
    }

    // A miniature screen with each app's icon drawn in the slot it fills.
    private func templatePreview(_ slots: [LayoutTemplate.Slot]) -> NSView {
        let screen = CGRect(x: 0, y: 0, width: (Settings.iconSize * 1.6).rounded(), height: Settings.iconSize)
        let preview = NSView()
        preview.wantsLayer = true
        preview.layer?.cornerRadius = (screen.height * 0.08).rounded()
        preview.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.widthAnchor.constraint(equalToConstant: screen.width).isActive = true
        preview.heightAnchor.constraint(equalToConstant: screen.height).isActive = true
        for slot in slots {
            let rect = Layout.frame(slot.action, current: .zero, in: screen)
            let icon = iconView(bundleIcon(slot.bundleID), size: (min(rect.width, rect.height) * 0.8).rounded())
            preview.addSubview(icon)
            // Layout frames grow downward like Accessibility; AppKit views grow upward.
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: preview.leadingAnchor, constant: rect.midX),
                icon.centerYAnchor.constraint(equalTo: preview.topAnchor, constant: rect.midY),
            ])
        }
        return preview
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

    private func strip(_ s: Switcher, mode: Switcher.Mode, fontSize: CGFloat, scale: CGFloat, maxWidth: CGFloat, iconsWidth: CGFloat) -> NSView {
        let box = NSStackView()
        box.orientation = .vertical
        box.alignment = .centerX
        box.spacing = Self.gap
        let iconSpacing = (Self.gap * scale).rounded()
        let icons = NSStackView()
        icons.orientation = .vertical
        icons.alignment = .centerX
        icons.spacing = iconSpacing
        let size = Settings.iconSize
        let columns = Layout.stripColumns(count: s.apps.count, tile: size, spacing: iconSpacing, available: iconsWidth)
        var iconRow = NSStackView()
        for (index, pid) in s.apps.enumerated() {
            if index % columns == 0 {
                iconRow = NSStackView()
                iconRow.spacing = iconSpacing
                // Without this the stack can stretch to the dropdown width on re-render and pin the icon left.
                iconRow.setHuggingPriority(.required, for: .horizontal)
                icons.addArrangedSubview(iconRow)
            }
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
            iconRow.addArrangedSubview(tile)
        }
        box.addArrangedSubview(icons)
        let app = s.apps.indices.contains(s.appIndex) ? NSRunningApplication(processIdentifier: s.apps[s.appIndex])?.localizedName ?? "" : ""
        // burnedout: assumed "App · Title" format, title of the window ⌥ release would focus, app name alone when title is empty or equal
        let title = (s.selection ?? s.dropdown.first)?.title ?? ""
        let label = NSTextField(labelWithString: title.isEmpty || title == app ? app : app + " · " + title)
        label.font = .systemFont(ofSize: fontSize, weight: .medium); label.lineBreakMode = .byTruncatingTail; label.alignment = .center
        // burnedout: assumed label width max(icon row, 400pt × scale) capped at list width, fixed so the panel doesn't jump per title
        label.widthAnchor.constraint(equalToConstant: min(max(size, icons.fittingSize.width, (400 * scale).rounded()), maxWidth)).isActive = true
        box.addArrangedSubview(label)
        if s.mode == .strip {
            box.setCustomSpacing(2, after: label)
            box.addArrangedSubview(hint("W close all · Q quit", size: 11 * scale))
        }
        if mode == .strip {
            for line in hintLines(s.mode) {
                let stripHint = hint(line, size: 11 * scale)
                stripHint.setContentCompressionResistancePriority(.required, for: .horizontal)
                box.addArrangedSubview(stripHint)
            }
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
        let title = window.title.isEmpty || window.title == appName ? appName : window.title + " · " + appName
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
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: Self.gap), icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28 * scale), icon.heightAnchor.constraint(equalToConstant: 28 * scale),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: Self.gap), label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            pin.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -Self.gap), pin.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            pin.widthAnchor.constraint(equalToConstant: 28 * scale), pin.heightAnchor.constraint(equalToConstant: 28 * scale),
        ])
        if let badge = badge(index, size: 11 * scale, selected: selected, prefix: mode == .list ? "⌘" : "") {
            row.addSubview(badge)
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(equalTo: badge.leadingAnchor, constant: -Self.gap),
                badge.trailingAnchor.constraint(equalTo: pin.leadingAnchor, constant: -Self.gap), badge.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])
        } else {
            label.trailingAnchor.constraint(equalTo: pin.leadingAnchor, constant: -Self.gap).isActive = true
        }
        return row
    }

    private func quickNavBox(_ s: Switcher, bookmarkHint: String?, fontSize: CGFloat, scale: CGFloat, rowHeight: CGFloat) -> NSView {
        let width = (Self.quickNavBaseWidth * scale).rounded()
        let box = NSStackView()
        box.orientation = .vertical; box.alignment = .leading; box.spacing = 2
        let title = NSTextField(labelWithString: "Quick nav")
        title.font = .systemFont(ofSize: 11 * scale, weight: .semibold)
        title.textColor = .secondaryLabelColor
        title.alignment = .center
        title.widthAnchor.constraint(equalToConstant: width - 2 * Self.gap).isActive = true
        box.addArrangedSubview(title)
        box.setCustomSpacing(Self.gap, after: title)
        for (index, url) in s.quickNav.enumerated() {
            let selected = s.mode == .quickNav && index == s.quickNavRow
            let row = RowView(index: index, onKey: onKey, click: [.openQuickNav(index)])
            row.wantsLayer = true
            row.layer?.cornerRadius = 8 * scale
            row.layer?.backgroundColor = selected ? NSColor.selectedContentBackgroundColor.cgColor : NSColor.clear.cgColor
            let icon = iconView(url.quickNavIcon, size: 28 * scale)
            let label = NSTextField(labelWithString: url.quickNavName)
            label.font = .systemFont(ofSize: fontSize, weight: selected ? .semibold : .regular); label.textColor = selected ? .white : .labelColor
            label.lineBreakMode = .byTruncatingMiddle
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            row.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalToConstant: width - 2 * Self.gap), row.heightAnchor.constraint(equalToConstant: rowHeight),
                label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])
            row.addSubview(icon)
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: Self.gap), icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: Self.gap),
            ])
            if let badge = badge(index, size: 11 * scale, selected: selected, prefix: "⌘") {
                row.addSubview(badge)
                NSLayoutConstraint.activate([
                    label.trailingAnchor.constraint(lessThanOrEqualTo: badge.leadingAnchor, constant: -Self.gap),
                    badge.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -Self.gap),
                    badge.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                ])
            } else {
                label.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -Self.gap).isActive = true
            }
            box.addArrangedSubview(row)
        }
        let footer = s.mode == .quickNav ? ["↑↓ move · ← back · − remove", "release ⌥ to open"] : [bookmarkHint].compactMap { $0 }
        if !footer.isEmpty, let last = box.arrangedSubviews.last { box.setCustomSpacing(Self.gap, after: last) }
        for line in footer {
            let label = hint(line, size: 11 * scale, width: width - 2 * Self.gap)
            label.alignment = .center
            box.addArrangedSubview(label)
        }
        return box
    }

    // Compact (previews and ⇧N) until ← enters the box, then wide enough to show each template's app names under its preview.
    private func templatesBox(_ s: Switcher, fontSize: CGFloat, scale: CGFloat) -> (box: NSView, selected: NSView?) {
        let expanded = s.mode == .templates
        let compactWidth = (Settings.iconSize * 1.6).rounded() + (24 * scale).rounded() + 3 * Self.gap
        let rowWidth = expanded ? max((Self.quickNavBaseWidth * scale).rounded() - 2 * Self.gap, compactWidth) : compactWidth
        var selectedRow: NSView?
        let box = NSStackView()
        box.orientation = .vertical; box.alignment = .leading; box.spacing = 2
        let title = NSTextField(labelWithString: "Templates")
        title.font = .systemFont(ofSize: 11 * scale, weight: .semibold)
        title.textColor = .secondaryLabelColor
        title.alignment = .center
        title.widthAnchor.constraint(equalToConstant: rowWidth).isActive = true
        box.addArrangedSubview(title)
        box.setCustomSpacing(Self.gap, after: title)
        if let draft = s.draft {
            let preview = templatePreview(draft)
            preview.alphaValue = 0.5
            let draftHint = hint(expanded ? "= save this layout" : "← then = save", size: 11 * scale)
            let row = NSStackView(views: [preview, draftHint])
            row.orientation = .vertical; row.alignment = .leading; row.spacing = 4 * scale
            row.edgeInsets = NSEdgeInsets(top: 0, left: Self.gap, bottom: 0, right: Self.gap)
            box.addArrangedSubview(row)
            box.setCustomSpacing(Self.gap, after: row)
        }
        for (index, template) in s.templates.enumerated() {
            let selected = expanded && index == s.templatesRow
            let row = RowView(index: index, onKey: onKey, click: [.applyTemplate(index)])
            row.wantsLayer = true
            row.layer?.cornerRadius = 8 * scale
            row.layer?.backgroundColor = selected ? NSColor.selectedContentBackgroundColor.cgColor : NSColor.clear.cgColor
            if selected { selectedRow = row }
            let top = NSStackView(views: [templatePreview(template.slots)])
            top.spacing = Self.gap
            if let badge = badge(index, size: 11 * scale, selected: selected, prefix: "⇧") { top.addArrangedSubview(badge) }
            let content = NSStackView(views: [top])
            content.orientation = .vertical; content.alignment = .leading; content.spacing = 4 * scale
            if expanded {
                let label = NSTextField(wrappingLabelWithString: template.name)
                label.font = .systemFont(ofSize: fontSize, weight: selected ? .semibold : .regular); label.textColor = selected ? .white : .labelColor
                label.preferredMaxLayoutWidth = rowWidth - 2 * Self.gap
                content.addArrangedSubview(label)
            }
            row.addSubview(content)
            content.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalToConstant: rowWidth),
                content.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: Self.gap),
                content.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -Self.gap),
                content.topAnchor.constraint(equalTo: row.topAnchor, constant: Self.gap),
                content.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -Self.gap),
            ])
            box.addArrangedSubview(row)
        }
        let footer =
            expanded ? ["↑↓ move · → back", "= save · − remove", "release ⌥ to apply"] : s.templates.isEmpty && s.draft == nil ? ["no templates"] : []
        if !footer.isEmpty, let last = box.arrangedSubviews.last { box.setCustomSpacing(Self.gap, after: last) }
        for line in footer {
            let label = hint(line, size: 11 * scale, width: rowWidth)
            label.alignment = .center
            box.addArrangedSubview(label)
        }
        return (box, selectedRow)
    }

    private func badge(_ index: Int, size: CGFloat, selected: Bool, prefix: String = "") -> NSView? {
        // Letters only apply to plain ⌥ shortcuts; ⌘ (search, quick nav) and ⇧ (templates) stay 1–9.
        guard index < (prefix.isEmpty ? Switcher.shortcutLabels.count : 9) else { return nil }
        let label = NSTextField(labelWithString: prefix + Switcher.shortcutLabels[index])
        label.font = .monospacedDigitSystemFont(ofSize: size, weight: .medium)
        label.textColor = selected ? .white : .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // Keys in the strip and dropdown are pressed while ⌥ is still held, so the hints leave ⌥ out.
    private func hintLines(_ mode: Switcher.Mode) -> [String] {
        switch mode {
        case .strip: return ["⇥ next app · ↑ search · ↓ windows · ← templates · → quick nav"]
        case .dropdown: return ["↑↓ move · ⇥ next app · ← templates · → quick nav · release ⌥ to switch", "= pin · W close window"]
        case .quickNav, .templates, .list, .closed: return []
        }
    }

    private func hint(_ text: String, size: CGFloat, width: CGFloat? = nil) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        let system = NSFont.systemFont(ofSize: size)
        label.font = system.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? system
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
    let click: [Switcher.Key]

    init(index: Int, onKey: @escaping (Switcher.Key) -> Void, click: [Switcher.Key]? = nil) {
        self.index = index
        self.onKey = onKey
        self.click = click ?? [.select(index), .enter]
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { click.forEach(onKey) }
}

// Keeps scrolled content anchored to the top instead of AppKit's default bottom.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
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
    @MainActor var quickNavIcon: NSImage {
        isFileURL ? NSWorkspace.shared.icon(forFile: path) : NSImage(systemSymbolName: "globe", accessibilityDescription: "Web page") ?? NSImage()
    }

    var quickNavName: String {
        guard isFileURL else {
            let name = (host ?? "") + path
            return name.isEmpty ? absoluteString : name
        }
        let name = FileManager.default.displayName(atPath: path)
        return hasDirectoryPath && pathExtension != "app" ? "\(name) (folder)" : name
    }
}
