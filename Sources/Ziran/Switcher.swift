import CoreGraphics
import Darwin
import Foundation

struct Switcher {
    enum Mode: Equatable { case closed, strip, dropdown, list, quickNav, templates }
    enum Key: Equatable {
        case tab, shiftTab, nextWindow, previousWindow, up, down, left, right, enter, escape, optionUp, closeWindow, quitApp, bookmark,
            windowClosed(CGWindowID), appQuit(pid_t), query(String), select(Int), pin(CGWindowID), jump(Int), openQuickNav(Int), quickNavChanged([URL]),
            applyTemplate(Int), selectTemplate(Int), templatesChanged([LayoutTemplate]), saveTemplate, removeTemplate(Int), removeQuickNav(Int)
    }
    enum Effect: Equatable {
        case none, update, focus(WindowInfo), close, closeWindow(WindowInfo), closeWindows([WindowInfo]), quitApp(pid_t), open(URL), toggleBookmark(WindowInfo),
            removeBookmark(URL), applyTemplate(LayoutTemplate), saveTemplate, removeTemplate(LayoutTemplate)
    }

    // Q and W are skipped because ⌥Q quits and ⌥W closes.
    static let shortcutLabels = (1...9).map(String.init) + "ABCDEFGHIJKLMNOPRSTUVXYZ".map(String.init)

    private(set) var mode: Mode = .closed
    private(set) var appIndex = 0
    private(set) var row = 0
    private(set) var query = ""
    private(set) var windows: [WindowInfo] = []
    private(set) var pins: [CGWindowID] = []
    private(set) var quickNav: [URL] = []
    private(set) var quickNavRow = 0
    private(set) var quickNavReturn = Mode.strip
    private(set) var templates: [LayoutTemplate] = []
    private(set) var templatesRow = 0
    private(set) var templatesReturn = Mode.strip
    private(set) var draftSlots: [LayoutTemplate.Slot] = []

    var apps: [pid_t] { MRU.apps(windows.filter { !$0.isMinimized }) }
    var dropdown: [WindowInfo] {
        guard apps.indices.contains(appIndex) else { return [] }
        return pinnedFirst(windows.filter { !$0.isMinimized && $0.pid == apps[appIndex] })
    }
    var list: [WindowInfo] { pinnedFirst(MRU.filter(query, windows)) }
    var pinned: [WindowInfo] { pins.compactMap { id in windows.first { $0.id == id } } }
    var draft: [LayoutTemplate.Slot]? {
        guard !draftSlots.isEmpty, !templates.contains(where: { Set($0.slots) == Set(draftSlots) }) else { return nil }
        return draftSlots
    }
    var selection: WindowInfo? {
        switch mode {
        case .strip: return dropdown.first
        case .dropdown: return dropdown.indices.contains(row) ? dropdown[row] : nil
        case .list: return list.indices.contains(row) ? list[row] : nil
        case .closed, .quickNav, .templates: return nil
        }
    }

    mutating func open(
        _ ordered: [WindowInfo], app pid: pid_t? = nil, quickNav: [URL] = [], templates: [LayoutTemplate] = [], draft: [LayoutTemplate.Slot] = []
    ) -> Effect {
        windows = pid.map { MRU.windows(of: $0, in: ordered) } ?? ordered
        self.quickNav = quickNav
        self.templates = templates
        draftSlots = draft
        quickNavRow = 0
        mode = pid == nil ? .strip : .dropdown
        appIndex = pid == nil && apps.count > 1 ? 1 : 0
        // Pins sort first, so pick the first listed window that isn't the current one rather than row 1.
        row = pid == nil ? 0 : dropdown.firstIndex { $0 != windows.first } ?? 0
        query = ""
        return apps.isEmpty ? close() : .update
    }

    mutating func handle(_ key: Key) -> Effect {
        guard mode != .closed else { return .none }
        if case .quickNavChanged(let urls) = key {
            quickNav = urls
            quickNavRow = min(quickNavRow, max(0, urls.count - 1))
            if mode == .quickNav && urls.isEmpty { mode = quickNavReturn }
            return .update
        }
        if case .templatesChanged(let values) = key {
            templates = values
            templatesRow = min(templatesRow, max(0, values.count - 1))
            return .update
        }
        if key == .saveTemplate, mode != .list { return .saveTemplate }
        if case .removeTemplate(let index) = key {
            guard mode != .list, templates.indices.contains(index) else { return .none }
            return .removeTemplate(templates[index])
        }
        if case .removeQuickNav(let index) = key {
            guard mode != .list, quickNav.indices.contains(index) else { return .none }
            return .removeBookmark(quickNav[index])
        }
        if case .applyTemplate(let index) = key {
            guard mode != .list, templates.indices.contains(index) else { return .none }
            return finish(.applyTemplate(templates[index]))
        }
        if mode == .templates {
            switch key {
            case .up: templatesRow = max(0, templatesRow - 1); return .update
            case .down: templatesRow = min(templatesRow + 1, max(0, templates.count - 1)); return .update
            case .right: mode = templatesReturn; return .update
            case .enter, .optionUp: return templates.indices.contains(templatesRow) ? finish(.applyTemplate(templates[templatesRow])) : close()
            case .saveTemplate: return .saveTemplate
            case .bookmark: return handle(.removeTemplate(templatesRow))
            case .selectTemplate(let index):
                guard templates.indices.contains(index) else { return .none }
                templatesRow = index
                return .update
            case .escape: return close()
            case .tab, .shiftTab, .nextWindow, .previousWindow, .left, .closeWindow, .quitApp, .windowClosed, .appQuit, .query, .pin, .jump,
                .openQuickNav, .quickNavChanged, .applyTemplate, .templatesChanged, .select, .removeTemplate, .removeQuickNav:
                return .none
            }
        }
        if case .openQuickNav(let index) = key {
            guard mode != .list, quickNav.indices.contains(index) else { return .none }
            return finish(.open(quickNav[index]))
        }
        if mode == .quickNav {
            switch key {
            case .up: quickNavRow = max(0, quickNavRow - 1); return .update
            case .down: quickNavRow = min(quickNavRow + 1, quickNav.count - 1); return .update
            case .left: mode = quickNavReturn; return .update
            case .enter, .optionUp: return quickNav.indices.contains(quickNavRow) ? finish(.open(quickNav[quickNavRow])) : close()
            case .bookmark: return handle(.removeQuickNav(quickNavRow))
            case .escape: return close()
            case .tab, .shiftTab, .nextWindow, .previousWindow, .right, .closeWindow, .quitApp, .windowClosed, .appQuit, .query, .select, .pin, .jump,
                .openQuickNav, .quickNavChanged, .applyTemplate, .templatesChanged, .saveTemplate, .selectTemplate, .removeTemplate, .removeQuickNav:
                return .none
            }
        }
        if case .pin(let id) = key {
            let selected = selection
            if let index = pins.firstIndex(of: id) { pins.remove(at: index) } else { pins.append(id) }
            if let selected, mode == .list, let index = list.firstIndex(of: selected) { row = index }
            if let selected, mode == .dropdown, let index = dropdown.firstIndex(of: selected) { row = index }
            return .update
        }
        if case .jump(let index) = key {
            guard handle(.select(index)) == .update else { return .none }
            return mode == .strip ? selection.map { finish(.focus($0)) } ?? close() : handle(.enter)
        }
        if case .select(let index) = key {
            switch mode {
            case .strip:
                guard apps.indices.contains(index) else { return .none }
                appIndex = index; row = 0
            case .dropdown:
                guard dropdown.indices.contains(index) else { return .none }
                row = index
            case .list:
                guard list.indices.contains(index) else { return .none }
                row = index
            case .closed, .quickNav, .templates: return .none
            }
            return .update
        }
        if key == .closeWindow {
            if mode == .strip {
                guard apps.indices.contains(appIndex) else { return .none }
                let pid = apps[appIndex]
                return .closeWindows(windows.filter { $0.pid == pid })
            }
            guard let window = selection else { return .none }
            return .closeWindow(window)
        }
        if key == .quitApp {
            guard mode == .strip, apps.indices.contains(appIndex) else { return .none }
            return .quitApp(apps[appIndex])
        }
        if case .appQuit(let pid) = key {
            guard mode == .strip, apps.contains(pid) else { return .none }
            windows.removeAll { $0.pid == pid }
            pins.removeAll { id in !windows.contains { $0.id == id } }
            guard !apps.isEmpty else { return close() }
            appIndex = min(appIndex, apps.count - 1)
            row = 0
            return .update
        }
        if case .windowClosed(let id) = key {
            guard windows.contains(where: { $0.id == id }) else { return .none }
            let app = apps.indices.contains(appIndex) ? apps[appIndex] : nil
            windows.removeAll { $0.id == id }
            pins.removeAll { $0 == id }
            if mode == .strip {
                guard !apps.isEmpty else { return close() }
                // When the selected app's last window closes, keep the slot so the next app takes its place.
                appIndex = apps.firstIndex { $0 == app } ?? min(appIndex, apps.count - 1)
                return .update
            }
            // Removing a window can reorder or drop apps, so re-find the selected app.
            appIndex = apps.firstIndex { $0 == app } ?? 0
            let remaining = mode == .list ? list.count : (apps.contains { $0 == app } ? dropdown.count : 0)
            guard remaining > 0 else { return close() }
            row = min(row, remaining - 1)
            return .update
        }
        if key == .escape { return close() }
        if mode == .list {
            switch key {
            case .up: row = max(0, row - 1); return .update
            case .down: row = min(row + 1, max(0, list.count - 1)); return .update
            case .query(let value): query = value; row = 0; return .update
            case .enter:
                guard let selection else { return close() }
                return finish(.focus(selection))
            case .tab, .shiftTab, .nextWindow, .previousWindow, .left, .right, .optionUp, .escape, .closeWindow, .quitApp, .bookmark, .windowClosed, .appQuit,
                .select, .pin, .jump, .openQuickNav, .quickNavChanged, .applyTemplate, .templatesChanged, .saveTemplate, .selectTemplate, .removeTemplate,
                .removeQuickNav:
                return .none
            }
        }
        switch key {
        case .tab, .shiftTab:
            guard mode == .strip || mode == .dropdown, !apps.isEmpty else { return .none }
            appIndex = (appIndex + (key == .tab ? 1 : apps.count - 1)) % apps.count
            row = 0
            return .update
        case .nextWindow, .previousWindow:
            guard !dropdown.isEmpty else { return .none }
            if mode == .strip {
                mode = .dropdown; row = 0
            } else {
                row = (row + (key == .nextWindow ? 1 : dropdown.count - 1)) % dropdown.count
            }
            return .update
        case .down:
            if mode == .strip { mode = .dropdown; row = 0 } else { row = min(row + 1, max(0, dropdown.count - 1)) }
            return .update
        case .up:
            if mode == .dropdown && row > 0 { row -= 1 } else { mode = .list; row = 0; query = "" }
            return .update
        case .right:
            guard !quickNav.isEmpty else { return .none }
            quickNavReturn = mode; mode = .quickNav; quickNavRow = 0
            return .update
        case .left:
            templatesReturn = mode; mode = .templates; templatesRow = 0
            return .update
        case .bookmark: return selection.map { .toggleBookmark($0) } ?? .none
        case .query, .escape, .closeWindow, .quitApp, .windowClosed, .appQuit, .select, .pin, .jump, .openQuickNav, .quickNavChanged, .applyTemplate,
            .templatesChanged, .saveTemplate, .selectTemplate, .removeTemplate, .removeQuickNav:
            return .none
        case .enter, .optionUp:
            if mode == .strip && apps.count < 2 { return close() }
            guard let selection else { return close() }
            return finish(.focus(selection))
        }
    }

    private mutating func finish(_ effect: Effect) -> Effect {
        mode = .closed; appIndex = 0; row = 0; quickNavRow = 0; query = ""; return effect
    }

    private mutating func close() -> Effect { finish(.close) }

    private func pinnedFirst(_ windows: [WindowInfo]) -> [WindowInfo] {
        pins.compactMap { id in windows.first { $0.id == id } } + windows.filter { !pins.contains($0.id) }
    }
}
