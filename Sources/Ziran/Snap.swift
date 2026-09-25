import CoreGraphics
import Carbon.HIToolbox

enum SnapAction: CaseIterable, Equatable {
    case leftHalf, rightHalf, topHalf, bottomHalf, maximize, center
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
    case topLeft, topRight, bottomLeft, bottomRight, nextDisplay, previousDisplay

    var keyCode: Int {
        switch self {
        case .leftHalf, .previousDisplay: kVK_LeftArrow
        case .rightHalf, .nextDisplay: kVK_RightArrow
        case .topHalf: kVK_UpArrow
        case .bottomHalf: kVK_DownArrow
        case .maximize: kVK_Return
        case .center: kVK_ANSI_C
        case .firstThird: kVK_ANSI_D
        case .centerThird: kVK_ANSI_F
        case .lastThird: kVK_ANSI_G
        case .firstTwoThirds: kVK_ANSI_E
        case .lastTwoThirds: kVK_ANSI_T
        case .topLeft: kVK_ANSI_U
        case .topRight: kVK_ANSI_I
        case .bottomLeft: kVK_ANSI_J
        case .bottomRight: kVK_ANSI_K
        }
    }

    var modifiers: Int {
        let base = Int(controlKey | optionKey)
        return self == .nextDisplay || self == .previousDisplay ? base | Int(cmdKey) : base
    }

    func frame(visible v: CGRect, current: CGRect) -> CGRect {
        let halfW = v.width / 2, halfH = v.height / 2
        switch self {
        case .leftHalf: return CGRect(x: v.minX, y: v.minY, width: halfW, height: v.height)
        case .rightHalf: return CGRect(x: v.midX, y: v.minY, width: halfW, height: v.height)
        case .topHalf: return CGRect(x: v.minX, y: v.midY, width: v.width, height: halfH)
        case .bottomHalf: return CGRect(x: v.minX, y: v.minY, width: v.width, height: halfH)
        case .maximize: return v
        case .center:
            let size = CGSize(width: min(current.width, v.width), height: min(current.height, v.height))
            let x: CGFloat = v.midX - size.width / 2
            let y: CGFloat = v.midY - size.height / 2
            return CGRect(x: x, y: y, width: size.width, height: size.height)
        case .topLeft: return CGRect(x: v.minX, y: v.midY, width: halfW, height: halfH)
        case .topRight: return CGRect(x: v.midX, y: v.midY, width: halfW, height: halfH)
        case .bottomLeft: return CGRect(x: v.minX, y: v.minY, width: halfW, height: halfH)
        case .bottomRight: return CGRect(x: v.midX, y: v.minY, width: halfW, height: halfH)
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds:
            let landscape = v.width >= v.height
            let length = landscape ? v.width : v.height
            let third = floor(length / 3)
            let twoThirds = floor(length * 2 / 3)
            let isTwo = self == .firstTwoThirds || self == .lastTwoThirds
            let extent = isTwo ? twoThirds : third
            let first = self == .firstThird || self == .firstTwoThirds
            let last = self == .lastThird || self == .lastTwoThirds
            if landscape {
                let x = first ? v.minX : last ? v.maxX - extent : v.minX + third
                let width = self == .centerThird ? v.width - 2 * third : extent
                return CGRect(x: x, y: v.minY, width: width, height: v.height)
            }
            let y = first ? v.maxY - extent : last ? v.minY : v.minY + third
            let height = self == .centerThird ? v.height - 2 * third : extent
            return CGRect(x: v.minX, y: y, width: v.width, height: height)
        case .nextDisplay, .previousDisplay: return current
        }
    }

    static func moved(_ current: CGRect, from: CGRect, to: CGRect) -> CGRect {
        guard from.width != 0, from.height != 0 else { return current }
        let sx = to.width / from.width, sy = to.height / from.height
        return CGRect(x: to.minX + (current.minX - from.minX) * sx,
                     y: to.minY + (current.minY - from.minY) * sy,
                     width: current.width * sx, height: current.height * sy)
    }
}
