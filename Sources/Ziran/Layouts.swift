import ApplicationServices
import CoreGraphics
import Foundation

struct Layout: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var bundleId: String
        var title: String
        var frame: CGRect
    }
    var name: String
    var entries: [Entry]
}

enum Layouts {
    static let fileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Ziran", isDirectory: true).appendingPathComponent("layouts.json")

    static func load(from url: URL = fileURL) throws -> [Layout] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([Layout].self, from: Data(contentsOf: url))
    }

    static func save(_ layouts: [Layout], to url: URL = fileURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(layouts)
        try data.write(to: url, options: .atomic)
    }

    static func match(_ entries: [Layout.Entry], _ windows: [WindowInfo]) -> [(entry: Layout.Entry, window: WindowInfo)] {
        var unused = Set(windows.indices)
        var matched = Set<Int>()
        var result: [(index: Int, entry: Layout.Entry, window: WindowInfo)] = []
        for pass in 1...3 {
            for (entryIndex, entry) in entries.enumerated() {
                guard !matched.contains(entryIndex) else { continue }
                guard let index = windows.indices.first(where: { index in
                    guard unused.contains(index) else { return false }
                    let window = windows[index]
                    guard window.bundleId == entry.bundleId else { return false }
                    switch pass {
                    case 1: return window.title == entry.title
                    case 2:
                        let prefix = String(entry.title.prefix(20))
                        return !prefix.isEmpty && !window.title.isEmpty && window.title.hasPrefix(prefix)
                    default: return true
                    }
                }) else { continue }
                unused.remove(index)
                matched.insert(entryIndex)
                result.append((entryIndex, entry, windows[index]))
            }
        }
        return entries.indices.compactMap { index in result.first { $0.index == index }.map { ($0.entry, $0.window) } }
    }

    @MainActor static func capture(name: String, tracker: WindowTracker) -> Layout {
        let entries = tracker.snapshot().filter { !$0.isMinimized }.compactMap { window -> Layout.Entry? in
            guard let frame = tracker.element(window.id).flatMap(AX.frame) else { return nil }
            return Layout.Entry(bundleId: window.bundleId, title: window.title, frame: frame)
        }
        return Layout(name: name, entries: entries)
    }

    @MainActor static func restore(_ layout: Layout, tracker: WindowTracker) {
        let windows = tracker.snapshot()
        for (entry, window) in match(layout.entries, windows) {
            if let element = tracker.element(window.id) { AX.setFrame(element, entry.frame) }
        }
    }
}
