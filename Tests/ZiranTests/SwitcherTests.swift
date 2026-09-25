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

@Test func switcherPins() {
    var switcher = Switcher()
    _ = switcher.open(fixture)
    #expect(switcher.handle(.pin(5)) == .update)
    #expect(switcher.list.first == fixture[4])
    #expect(switcher.pinned == [fixture[4]])
    #expect(switcher.handle(.pin(5)) == .update)
    #expect(switcher.list == fixture)
    _ = switcher.handle(.pin(5))
    _ = switcher.handle(.escape)
    _ = switcher.open(fixture)
    #expect(switcher.list.first == fixture[4])
    _ = switcher.handle(.up)
    _ = switcher.handle(.query("gam"))
    #expect(switcher.list == [fixture[4]])
    _ = switcher.handle(.query("alp"))
    #expect(switcher.list == [fixture[0], fixture[1]])
}

@Test(arguments: [
    ([Switcher.Key.select(2)], Switcher.Effect.update, Switcher.Mode.strip, 0, 2),
    ([Switcher.Key.down, .select(0)], .update, .dropdown, 0, 1),
    ([Switcher.Key.up, .select(3)], .update, .list, 3, 1),
    ([Switcher.Key.select(99)], .none, .strip, 0, 1),
    ([Switcher.Key.up, .select(-1)], .none, .list, 0, 1)
])
func switcherSelect(keys: [Switcher.Key], effect: Switcher.Effect, mode: Switcher.Mode, row: Int, appIndex: Int) {
    var switcher = Switcher()
    _ = switcher.open(fixture)
    var actual = Switcher.Effect.update
    for key in keys { actual = switcher.handle(key) }
    #expect(actual == effect)
    #expect(switcher.mode == mode)
    #expect(switcher.row == row)
    #expect(switcher.appIndex == appIndex)
}
