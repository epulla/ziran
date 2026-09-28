import Darwin
import CoreGraphics

struct Switcher {
    enum Mode: Equatable { case closed, strip, dropdown, list }
    enum Key: Equatable {
        case tab, shiftTab, nextWindow, previousWindow, up, down, enter, escape, optionUp, query(String), select(Int), pin(CGWindowID), jump(Int)
    }
    enum Effect: Equatable { case none, update, focus(WindowInfo), close }

    private(set) var mode: Mode = .closed
    private(set) var appIndex = 0
    private(set) var row = 0
    private(set) var query = ""
    private(set) var windows: [WindowInfo] = []
    private(set) var pins: [CGWindowID] = []

    var apps: [pid_t] { MRU.apps(windows.filter { !$0.isMinimized }) }
    var dropdown: [WindowInfo] {
        guard apps.indices.contains(appIndex) else { return [] }
        return pinnedFirst(windows.filter { !$0.isMinimized && $0.pid == apps[appIndex] })
    }
    var list: [WindowInfo] { pinnedFirst(MRU.filter(query, windows)) }
    var pinned: [WindowInfo] { pins.compactMap { id in windows.first { $0.id == id } } }
    var selection: WindowInfo? {
        switch mode {
        case .strip: return dropdown.first
        case .dropdown: return dropdown.indices.contains(row) ? dropdown[row] : nil
        case .list: return list.indices.contains(row) ? list[row] : nil
        case .closed: return nil
        }
    }

    mutating func open(_ ordered: [WindowInfo], app pid: pid_t? = nil) -> Effect {
        windows = pid.map { MRU.windows(of: $0, in: ordered) } ?? ordered
        mode = pid == nil ? .strip : .dropdown
        appIndex = pid == nil && apps.count > 1 ? 1 : 0
        // Pins sort first, so pick the first listed window that isn't the current one rather than row 1.
        row = pid == nil ? 0 : dropdown.firstIndex { $0 != windows.first } ?? 0
        query = ""
        return apps.isEmpty ? close() : .update
    }

    mutating func handle(_ key: Key) -> Effect {
        guard mode != .closed else { return .none }
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
            case .closed: return .none
            }
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
            case .tab, .shiftTab, .nextWindow, .previousWindow, .optionUp, .escape, .select, .pin, .jump: return .none
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
        case .query, .escape, .select, .pin, .jump: return .none
        case .enter, .optionUp:
            if mode == .strip && apps.count < 2 { return close() }
            guard let selection else { return close() }
            return finish(.focus(selection))
        }
    }

    private mutating func finish(_ effect: Effect) -> Effect {
        mode = .closed; appIndex = 0; row = 0; query = ""; return effect
    }

    private mutating func close() -> Effect { finish(.close) }

    private func pinnedFirst(_ windows: [WindowInfo]) -> [WindowInfo] {
        pins.compactMap { id in windows.first { $0.id == id } } + windows.filter { !pins.contains($0.id) }
    }
}
