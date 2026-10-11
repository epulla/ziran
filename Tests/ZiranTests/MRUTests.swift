import CoreGraphics
import Foundation
import Testing
@testable import Ziran

private let mruWindows = [
    WindowInfo(id: 1, pid: 1, bundleId: "a", appName: "Alpha", title: "One", isMinimized: false),
    WindowInfo(id: 2, pid: 2, bundleId: "b", appName: "Beta", title: "Two", isMinimized: false),
    WindowInfo(id: 3, pid: 1, bundleId: "a", appName: "Alpha", title: "Three", isMinimized: false),
]

@Test func mruOrderingAndGroups() {
    let ordered = MRU.order(mruWindows, lastFocus: [2: Date(timeIntervalSince1970: 2)], appActivation: [:], zOrder: [3, 1, 2])
    #expect(ordered.map(\.id) == [2, 3, 1])
    #expect(MRU.apps(ordered) == [2, 1])
    #expect(MRU.windows(of: 1, in: ordered).map(\.id) == [3, 1])
}

@Test func mruUnfocusedWindowsUseAppActivation() {
    let ordered = MRU.order(
        mruWindows, lastFocus: [2: Date(timeIntervalSince1970: 2)], appActivation: [1: Date(timeIntervalSince1970: 3)], zOrder: [3, 1, 2])
    #expect(ordered.map(\.id) == [3, 1, 2])
    #expect(MRU.apps(ordered) == [1, 2])
}

@Test(arguments: [("alp", [1, 3]), ("thr", [3]), ("btw", [2]), ("", [1, 2, 3]), ("  ", [1, 2, 3])])
func mruFilter(query: String, ids: [CGWindowID]) {
    #expect(MRU.filter(query, mruWindows).map(\.id) == ids)
}
