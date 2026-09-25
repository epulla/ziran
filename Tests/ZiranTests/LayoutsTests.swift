import CoreGraphics
import Foundation
import Testing
@testable import Ziran

private func entry(_ bundle: String, _ title: String, _ x: CGFloat = 0) -> Layout.Entry {
    Layout.Entry(bundleId: bundle, title: title, frame: CGRect(x: x, y: 1, width: 2, height: 3))
}
private func window(_ id: CGWindowID, _ bundle: String, _ title: String) -> WindowInfo {
    WindowInfo(id: id, pid: 1, bundleId: bundle, appName: bundle, title: title, isMinimized: false)
}

@Test func matchingUsesExactThenPrefixThenNthApp() {
    // "Alpha" would prefix-match window 2 first if exact matches were not resolved globally.
    let entries = [entry("a", "Alpha"), entry("a", "Alpha long title"), entry("a", "Other")]
    let windows = [window(2, "a", "Alpha long title"), window(1, "a", "Alpha extra"), window(3, "a", "Third")]
    #expect(Layouts.match(entries, windows).map { $0.window.id } == [1, 2, 3])
}

@Test func matchingSkipsMissingAppsAndReusesNoWindow() {
    let entries = [entry("missing", "Nope"), entry("a", "Same"), entry("a", "Same")]
    #expect(Layouts.match(entries, [window(1, "a", "Same")]).map { $0.window.id } == [1])
}

@Test func layoutRoundTripAndMissingLoad() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = dir.appendingPathComponent("layouts.json")
    let layouts = [Layout(name: "work", entries: [entry("a", "One", 4)])]
    #expect(try Layouts.load(from: url).isEmpty)
    try Layouts.save(layouts, to: url)
    #expect(try Layouts.load(from: url) == layouts)
}

@Test func corruptLayoutFileThrows() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data("not json".utf8).write(to: url)
    #expect(throws: (any Error).self) { try Layouts.load(from: url) }
}
