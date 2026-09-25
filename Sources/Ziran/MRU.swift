import CoreGraphics
import Foundation

struct WindowInfo: Equatable, Sendable {
    let id: CGWindowID
    let pid: pid_t
    let bundleId: String
    let appName: String
    let title: String
    let isMinimized: Bool
}

enum MRU {
    static func order(_ windows: [WindowInfo], lastFocus: [CGWindowID: Date], zOrder: [CGWindowID]) -> [WindowInfo] {
        let z = Dictionary(uniqueKeysWithValues: zOrder.enumerated().map { ($1, $0) })
        return windows.enumerated().sorted {
            let left = lastFocus[$0.element.id]
            let right = lastFocus[$1.element.id]
            if left != nil || right != nil {
                if left != right { return (left ?? .distantPast) > (right ?? .distantPast) }
                return $0.offset < $1.offset
            }
            let leftIndex = z[$0.element.id] ?? .max
            let rightIndex = z[$1.element.id] ?? .max
            return leftIndex == rightIndex ? $0.offset < $1.offset : leftIndex < rightIndex
        }.map(\.element)
    }

    static func apps(_ ordered: [WindowInfo]) -> [pid_t] {
        var seen = Set<pid_t>()
        return ordered.compactMap { seen.insert($0.pid).inserted ? $0.pid : nil }
    }

    static func windows(of pid: pid_t, in ordered: [WindowInfo]) -> [WindowInfo] {
        ordered.filter { $0.pid == pid }
    }

    static func filter(_ query: String, _ windows: [WindowInfo]) -> [WindowInfo] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return windows }
        return windows.filter { window in
            let characters = Array((window.appName + " " + window.title).lowercased())
            var index = 0
            return query.allSatisfy { character in
                while index < characters.count && characters[index] != character { index += 1 }
                guard index < characters.count else { return false }
                index += 1
                return true
            }
        }
    }
}
