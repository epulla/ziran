import Testing
@testable import Ziran

private let fixture = [
    WindowInfo(id: 1, pid: 1, bundleId: "a", appName: "Alpha", title: "One", isMinimized: false),
    WindowInfo(id: 2, pid: 1, bundleId: "a", appName: "Alpha", title: "Two", isMinimized: false),
    WindowInfo(id: 3, pid: 2, bundleId: "b", appName: "Beta", title: "Three", isMinimized: false),
    WindowInfo(id: 4, pid: 2, bundleId: "b", appName: "Beta", title: "Hidden", isMinimized: true),
    WindowInfo(id: 5, pid: 3, bundleId: "c", appName: "Gamma", title: "Four", isMinimized: false)
]

@Test(arguments: [
    ([Switcher.Key.optionUp], Switcher.Effect.focus(fixture[2]), Switcher.Mode.closed),
    ([.tab, .optionUp], .focus(fixture[4]), .closed),
    ([.tab, .tab, .optionUp], .focus(fixture[0]), .closed),
    ([.tab, .tab, .tab, .optionUp], .focus(fixture[2]), .closed),
    ([.shiftTab, .optionUp], .focus(fixture[0]), .closed),
    ([.shiftTab, .down, .down, .up, .optionUp], .focus(fixture[0]), .closed),
    ([.down, .up, .optionUp], .none, .list),
    ([.up, .query("gam"), .enter], .focus(fixture[4]), .closed),
    ([.escape], .close, .closed)
])
func switcherSequences(keys: [Switcher.Key], expected: Switcher.Effect, mode: Switcher.Mode) {
    var switcher = Switcher()
    _ = switcher.open(fixture)
    var effect = Switcher.Effect.update
    for key in keys { effect = switcher.handle(key) }
    #expect(effect == expected)
    #expect(switcher.mode == mode)
}

@Test func switcherSingleAppTapAndMinimizedList() {
    var switcher = Switcher()
    #expect(switcher.open([fixture[0]]) == .update)
    #expect(switcher.handle(.optionUp) == .close)
    #expect(switcher.mode == .closed)
    _ = switcher.open(fixture)
    #expect(switcher.dropdown.allSatisfy { !$0.isMinimized })
    #expect(switcher.list.contains(fixture[3]))
}
