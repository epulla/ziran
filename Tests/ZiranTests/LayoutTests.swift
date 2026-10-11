import CoreGraphics
import Testing
@testable import Ziran

private let screen = CGRect(x: 100, y: 25, width: 1200, height: 800)
private let loose = CGRect(x: 300, y: 100, width: 300, height: 200)

@Test(arguments: [
    (Layout.Action.leftHalf, loose, CGRect(x: 100, y: 25, width: 600, height: 800)),
    (.leftHalf, CGRect(x: 100, y: 25, width: 600, height: 800), CGRect(x: 100, y: 25, width: 800, height: 800)),
    (.leftHalf, CGRect(x: 100, y: 25, width: 800, height: 800), CGRect(x: 100, y: 25, width: 400, height: 800)),
    (.leftHalf, CGRect(x: 100, y: 25, width: 400, height: 800), CGRect(x: 100, y: 25, width: 600, height: 800)),
    (.leftHalf, CGRect(x: 100, y: 25, width: 590, height: 795), CGRect(x: 100, y: 25, width: 800, height: 800)),
    (.leftHalf, CGRect(x: 700, y: 25, width: 600, height: 800), CGRect(x: 100, y: 25, width: 600, height: 800)),
    (.rightHalf, loose, CGRect(x: 700, y: 25, width: 600, height: 800)),
    (.rightHalf, CGRect(x: 700, y: 25, width: 600, height: 800), CGRect(x: 500, y: 25, width: 800, height: 800)),
    (.rightHalf, CGRect(x: 500, y: 25, width: 800, height: 800), CGRect(x: 900, y: 25, width: 400, height: 800)),
    (.topHalf, CGRect(x: 100, y: 25, width: 1200, height: 400), CGRect(x: 100, y: 25, width: 1200, height: 400)),
    (.bottomHalf, loose, CGRect(x: 100, y: 425, width: 1200, height: 400)),
    (.topLeft, loose, CGRect(x: 100, y: 25, width: 600, height: 400)),
    (.topRight, loose, CGRect(x: 700, y: 25, width: 600, height: 400)),
    (.bottomLeft, loose, CGRect(x: 100, y: 425, width: 600, height: 400)),
    (.bottomRight, loose, CGRect(x: 700, y: 425, width: 600, height: 400)),
    (.maximize, loose, screen),
    (.center, loose, CGRect(x: 550, y: 325, width: 300, height: 200)),
    (.center, CGRect(x: 0, y: 0, width: 2000, height: 1000), screen),
])
func layoutFrames(action: Layout.Action, current: CGRect, expected: CGRect) {
    #expect(Layout.frame(action, current: current, in: screen) == expected)
}

@Test func layoutMoveKeepsRelativeFrame() {
    let target = CGRect(x: 1200, y: 0, width: 1920, height: 1080)
    #expect(Layout.move(CGRect(x: 700, y: 25, width: 600, height: 800), from: screen, to: target) == CGRect(x: 2160, y: 0, width: 960, height: 1080))
}
