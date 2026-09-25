import Darwin

struct Switcher {
    enum Mode: Equatable { case closed, strip, dropdown, list }
    enum Key: Equatable { case tab, shiftTab, up, down, enter, escape, optionUp, query(String) }
    enum Effect: Equatable { case none, update, focus(WindowInfo), close }

    private(set) var mode: Mode = .closed
    private(set) var appIndex = 0
    private(set) var row = 0
    private(set) var query = ""
    private(set) var windows: [WindowInfo] = []

    var apps: [pid_t] { MRU.apps(windows.filter { !$0.isMinimized }) }
    var dropdown: [WindowInfo] {
        guard apps.indices.contains(appIndex) else { return [] }
        return windows.filter { !$0.isMinimized && $0.pid == apps[appIndex] }
    }
    var list: [WindowInfo] { MRU.filter(query, windows) }
    var selection: WindowInfo? {
        switch mode {
        case .strip: return dropdown.first
        case .dropdown: return dropdown.indices.contains(row) ? dropdown[row] : nil
        case .list: return list.indices.contains(row) ? list[row] : nil
        case .closed: return nil
        }
    }

    mutating func open(_ ordered: [WindowInfo]) -> Effect {
        windows = ordered
        mode = .strip
        appIndex = apps.count > 1 ? 1 : 0
        row = 0
        query = ""
        return apps.isEmpty ? close() : .update
    }

    mutating func handle(_ key: Key) -> Effect {
        guard mode != .closed else { return .none }
        if key == .escape { return close() }
        if mode == .list {
            switch key {
            case .up: row = max(0, row - 1); return .update
            case .down: row = min(row + 1, max(0, list.count - 1)); return .update
            case .query(let value): query = value; row = 0; return .update
            case .enter:
                guard let selection else { return close() }
                return finish(.focus(selection))
            case .tab, .shiftTab, .optionUp, .escape: return .none
            }
        }
        switch key {
        case .tab, .shiftTab:
            guard mode == .strip || mode == .dropdown, !apps.isEmpty else { return .none }
            appIndex = (appIndex + (key == .tab ? 1 : apps.count - 1)) % apps.count
            row = 0
            return .update
        case .down:
            if mode == .strip { mode = .dropdown; row = 0 } else { row = min(row + 1, max(0, dropdown.count - 1)) }
            return .update
        case .up:
            if mode == .dropdown && row > 0 { row -= 1 } else { mode = .list; row = 0; query = "" }
            return .update
        case .query, .escape: return .none
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
}
