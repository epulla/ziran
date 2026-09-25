import CoreGraphics
import Testing
@testable import Ziran

private let landscape = CGRect(x: 0, y: 0, width: 1200, height: 900)
private let portrait = CGRect(x: 0, y: 0, width: 900, height: 1200)

@Test(arguments: [
    (SnapAction.leftHalf, landscape, CGRect(x: 0, y: 0, width: 600, height: 900)),
    (.rightHalf, landscape, CGRect(x: 600, y: 0, width: 600, height: 900)),
    (.topHalf, landscape, CGRect(x: 0, y: 450, width: 1200, height: 450)),
    (.bottomHalf, landscape, CGRect(x: 0, y: 0, width: 1200, height: 450)),
    (.maximize, landscape, landscape),
    (.firstThird, landscape, CGRect(x: 0, y: 0, width: 400, height: 900)),
    (.centerThird, landscape, CGRect(x: 400, y: 0, width: 400, height: 900)),
    (.lastThird, landscape, CGRect(x: 800, y: 0, width: 400, height: 900)),
    (.firstTwoThirds, landscape, CGRect(x: 0, y: 0, width: 800, height: 900)),
    (.lastTwoThirds, landscape, CGRect(x: 400, y: 0, width: 800, height: 900)),
    (.topLeft, landscape, CGRect(x: 0, y: 450, width: 600, height: 450)),
    (.topRight, landscape, CGRect(x: 600, y: 450, width: 600, height: 450)),
    (.bottomLeft, landscape, CGRect(x: 0, y: 0, width: 600, height: 450)),
    (.bottomRight, landscape, CGRect(x: 600, y: 0, width: 600, height: 450)),
    (.firstThird, portrait, CGRect(x: 0, y: 800, width: 900, height: 400)),
    (.lastThird, portrait, CGRect(x: 0, y: 0, width: 900, height: 400)),
    (.center, landscape, CGRect(x: 400, y: 300, width: 400, height: 300)),
    (.center, landscape, landscape)
])
func snapFrames(action: SnapAction, visible: CGRect, expected: CGRect) {
    let current = action == .center && expected == landscape ? CGRect(x: -50, y: -50, width: 1600, height: 1000) : CGRect(x: 100, y: 100, width: 400, height: 300)
    #expect(action.frame(visible: visible, current: current) == expected)
}

@Test func snapMovementAndFlip() {
    let current = CGRect(x: 100, y: 100, width: 400, height: 200)
    #expect(SnapAction.moved(current, from: CGRect(x: 0, y: 0, width: 1000, height: 800), to: CGRect(x: 1000, y: 0, width: 2000, height: 1600)) == CGRect(x: 1200, y: 200, width: 800, height: 400))
    let rect = CGRect(x: 20, y: 30, width: 100, height: 200)
    #expect(AX.flip(rect, primaryMaxY: 1000) == CGRect(x: 20, y: 770, width: 100, height: 200))
    #expect(AX.flip(AX.flip(rect, primaryMaxY: 1000), primaryMaxY: 1000) == rect)
}
