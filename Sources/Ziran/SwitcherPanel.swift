import AppKit

@MainActor
final class SwitcherPanel: NSPanel, NSSearchFieldDelegate {
    private let visualEffect = NSVisualEffectView()
    private let onKey: (Switcher.Key) -> Void
    private var search: NSTextField?
    var layoutsMenu: (() -> NSMenu)?

    init(onKey: @escaping (Switcher.Key) -> Void) {
        self.onKey = onKey
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 18
        visualEffect.layer?.masksToBounds = true
        contentView = visualEffect
    }

    override var canBecomeKey: Bool { true }

    func show(_ s: Switcher) {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .centerX
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        if s.mode == .list {
            let field = search ?? makeSearch()
            field.stringValue = s.query
            root.addArrangedSubview(field)
            let start = max(0, s.row - 11)
            for (index, window) in s.list.enumerated().dropFirst(start).prefix(12) { root.addArrangedSubview(row(window.appName + " — " + window.title, selected: index == s.row)) }
            let layouts = NSButton(title: "Layouts", target: self, action: #selector(showLayouts))
            layouts.isEnabled = layoutsMenu != nil
            root.addArrangedSubview(layouts)
        } else {
            search = nil
            root.addArrangedSubview(strip(s))
            if s.mode == .dropdown { for (index, window) in s.dropdown.enumerated() { root.addArrangedSubview(row(window.title.isEmpty ? window.appName : window.title, selected: index == s.row)) } }
        }
        visualEffect.subviews.forEach { $0.removeFromSuperview() }
        visualEffect.addSubview(root)
        root.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor), root.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            root.topAnchor.constraint(equalTo: visualEffect.topAnchor), root.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor)
        ])
        setContentSize(root.fittingSize)
        if let screen = NSScreen.main { setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - frame.width / 2, y: screen.visibleFrame.midY - frame.height / 2)) }
        orderFrontRegardless()
        if s.mode == .list { makeKey(); search?.becomeFirstResponder(); search?.currentEditor()?.selectedRange = NSRange(location: search?.stringValue.count ?? 0, length: 0) }
    }

    func hide() { orderOut(nil) }

    @objc private func showLayouts(_ button: NSButton) {
        guard let menu = layoutsMenu?() else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        onKey(.escape)
    }

    private func makeSearch() -> NSTextField {
        let field = NSSearchField()
        field.placeholderString = "Search windows"
        field.delegate = self
        search = field
        return field
    }

    private func strip(_ s: Switcher) -> NSView {
        let box = NSStackView()
        box.orientation = .vertical
        box.alignment = .centerX
        let icons = NSStackView()
        icons.spacing = 8
        for (index, pid) in s.apps.enumerated() {
            let view = NSImageView(image: NSRunningApplication(processIdentifier: pid)?.icon ?? NSImage())
            view.imageScaling = .scaleProportionallyUpOrDown
            let holder = NSView()
            holder.widthAnchor.constraint(equalToConstant: 64).isActive = true
            holder.heightAnchor.constraint(equalToConstant: 64).isActive = true
            holder.wantsLayer = true
            holder.layer?.cornerRadius = 12
            holder.layer?.backgroundColor = index == s.appIndex ? NSColor.white.withAlphaComponent(0.22).cgColor : NSColor.clear.cgColor
            holder.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([view.centerXAnchor.constraint(equalTo: holder.centerXAnchor), view.centerYAnchor.constraint(equalTo: holder.centerYAnchor), view.widthAnchor.constraint(equalToConstant: 48), view.heightAnchor.constraint(equalToConstant: 48)])
            icons.addArrangedSubview(holder)
        }
        box.addArrangedSubview(icons)
        let app = s.apps.indices.contains(s.appIndex) ? NSRunningApplication(processIdentifier: s.apps[s.appIndex])?.localizedName ?? "" : ""
        box.addArrangedSubview(NSTextField(labelWithString: app))
        return box
    }

    private func row(_ title: String, selected: Bool) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .left
        label.wantsLayer = true
        label.layer?.cornerRadius = 7
        label.layer?.backgroundColor = selected ? NSColor.white.withAlphaComponent(0.18).cgColor : NSColor.clear.cgColor
        return label
    }

    func controlTextDidChange(_ obj: Notification) { if let field = obj.object as? NSTextField { onKey(.query(field.stringValue)) } }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let key: Switcher.Key?
        switch commandSelector { case #selector(moveUp): key = .up; case #selector(moveDown): key = .down; case #selector(insertNewline): key = .enter; case #selector(cancelOperation): key = .escape; default: key = nil }
        if let key { onKey(key); return true }
        return false
    }
}
