import Darwin
import Testing
@testable import Ziran

private let fixture = [
    WindowInfo(id: 1, pid: 1, bundleId: "a", appName: "Alpha", title: "One", isMinimized: false),
    WindowInfo(id: 2, pid: 1, bundleId: "a", appName: "Alpha", title: "Two", isMinimized: false),
    WindowInfo(id: 3, pid: 2, bundleId: "b", appName: "Beta", title: "Three", isMinimized: false),
    WindowInfo(id: 4, pid: 2, bundleId: "b", appName: "Beta", title: "Hidden", isMinimized: true),
    WindowInfo(id: 5, pid: 3, bundleId: "c", appName: "Gamma", title: "Four", isMinimized: false),
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
    ([.escape], .close, .closed),
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

@Test func switcherPinKeepsSelection() {
    var switcher = Switcher()
    _ = switcher.open(fixture)
    _ = switcher.handle(.up)
    _ = switcher.handle(.down)
    _ = switcher.handle(.pin(5))
    #expect(switcher.selection == fixture[1])
    #expect(switcher.row == 2)
}

@Test(arguments: [
    ([Switcher.Key.jump(0)], Switcher.Effect.focus(fixture[0]), Switcher.Mode.closed),
    ([.jump(2)], .focus(fixture[4]), .closed),
    ([.tab, .tab, .down, .jump(1)], .focus(fixture[1]), .closed),
    ([.up, .jump(3)], .focus(fixture[3]), .closed),
    ([.jump(9)], .none, .strip),
])
func switcherJump(keys: [Switcher.Key], expected: Switcher.Effect, mode: Switcher.Mode) {
    var switcher = Switcher()
    _ = switcher.open(fixture)
    var effect = Switcher.Effect.update
    for key in keys { effect = switcher.handle(key) }
    #expect(effect == expected)
    #expect(switcher.mode == mode)
}

@Test func switcherJumpSingleApp() {
    var switcher = Switcher()
    _ = switcher.open([fixture[0]])
    #expect(switcher.handle(.jump(0)) == .focus(fixture[0]))
}

@Test(arguments: [
    ([Switcher.Key.select(2)], Switcher.Effect.update, Switcher.Mode.strip, 0, 2),
    ([Switcher.Key.down, .select(0)], .update, .dropdown, 0, 1),
    ([Switcher.Key.up, .select(3)], .update, .list, 3, 1),
    ([Switcher.Key.select(99)], .none, .strip, 0, 1),
    ([Switcher.Key.up, .select(-1)], .none, .list, 0, 1),
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

@Test(arguments: [
    (pid_t(1), Switcher.Effect.update, Switcher.Mode.dropdown, Switcher.Effect.focus(fixture[1])),
    (2, .update, .dropdown, .focus(fixture[2])),
    (9, .close, .closed, .none),
])
func switcherOpenApp(pid: pid_t, opened: Switcher.Effect, mode: Switcher.Mode, released: Switcher.Effect) {
    var switcher = Switcher()
    #expect(switcher.open(fixture, app: pid) == opened)
    #expect(switcher.mode == mode)
    #expect(switcher.handle(.optionUp) == released)
}

@Test func switcherOpenAppSearchesOnlyThatApp() {
    var switcher = Switcher()
    _ = switcher.open(fixture, app: 1)
    _ = switcher.handle(.up)
    _ = switcher.handle(.up)
    #expect(switcher.mode == .list)
    #expect(switcher.list == [fixture[0], fixture[1]])
}

@Test func switcherOpenAppSkipsCurrentWindowWhenPinned() {
    var switcher = Switcher()
    _ = switcher.open(fixture, app: 1)
    _ = switcher.handle(.pin(2))
    _ = switcher.handle(.escape)
    _ = switcher.open(fixture, app: 1)
    #expect(switcher.handle(.optionUp) == .focus(fixture[1]))
}

@Test(arguments: [
    ([Switcher.Key.nextWindow], fixture[0]),
    ([.nextWindow, .nextWindow], fixture[1]),
    ([.previousWindow, .previousWindow], fixture[1]),
    ([.down, .nextWindow], fixture[0]),
])
func switcherCyclesAppWindows(keys: [Switcher.Key], expected: WindowInfo) {
    var switcher = Switcher()
    _ = switcher.open(fixture, app: 1)
    for key in keys { _ = switcher.handle(key) }
    #expect(switcher.handle(.optionUp) == .focus(expected))
}

@Test(arguments: [
    (pid_t?(1), [Switcher.Key.closeWindow], Switcher.Effect.closeWindow(fixture[1]), Switcher.Effect.update, Switcher.Mode.dropdown),
    (1, [.pin(2), .closeWindow], .closeWindow(fixture[1]), .update, .dropdown),
    (nil, [.closeWindow], .none, .none, .strip),
    (nil, [.down, .closeWindow], .closeWindow(fixture[2]), .close, .closed),
    (nil, [.up, .down, .closeWindow], .closeWindow(fixture[1]), .update, .list),
])
func switcherClosesWindow(app: pid_t?, keys: [Switcher.Key], requested: Switcher.Effect, removed: Switcher.Effect, mode: Switcher.Mode) {
    var switcher = Switcher()
    _ = switcher.open(fixture, app: app)
    var effect = Switcher.Effect.update
    for key in keys { effect = switcher.handle(key) }
    #expect(effect == requested)
    if case .closeWindow(let window) = requested {
        #expect(switcher.windows.contains(window))
        if keys.contains(.pin(window.id)) { #expect(switcher.pins.contains(window.id)) }
        #expect(switcher.handle(.windowClosed(window.id)) == removed)
        #expect(!switcher.windows.contains(window))
    }
    #expect(switcher.mode == mode)
    #expect(switcher.pins.isEmpty)
}

@Test func switcherRetainsWindowWithoutClosureAndIgnoresLateNotification() {
    var switcher = Switcher()
    _ = switcher.open(fixture, app: 1)
    #expect(switcher.handle(.closeWindow) == .closeWindow(fixture[1]))
    #expect(switcher.dropdown == [fixture[0], fixture[1]])
    #expect(switcher.handle(.windowClosed(999)) == .none)
    #expect(switcher.handle(.escape) == .close)
    #expect(switcher.handle(.windowClosed(fixture[1].id)) == .none)
}

@Test func switcherClosesAfterLastWindowDisappears() {
    var switcher = Switcher()
    _ = switcher.open(fixture, app: 1)
    #expect(switcher.handle(.windowClosed(fixture[1].id)) == .update)
    #expect(switcher.handle(.closeWindow) == .closeWindow(fixture[0]))
    #expect(switcher.handle(.windowClosed(fixture[0].id)) == .close)
    #expect(switcher.mode == .closed)
}
