import CoreGraphics

// Frames use Accessibility coordinates: origin at the top-left of the primary screen, y grows downward.
enum Layout {
    enum Action: Equatable { case leftHalf, rightHalf, topHalf, bottomHalf, topLeft, topRight, bottomLeft, bottomRight, maximize, center }

    static func frame(_ action: Action, current: CGRect, in screen: CGRect) -> CGRect {
        let halfWidth = screen.width / 2
        let halfHeight = screen.height / 2
        let rect: CGRect
        switch action {
        case .leftHalf, .rightHalf:
            // Repeating a side half cycles 1/2 -> 2/3 -> 1/3; the tolerance absorbs apps like Terminal that snap their size to a grid.
            let tolerance: CGFloat = 20
            let fractions: [CGFloat] = [1 / 2, 2 / 3, 1 / 3]
            let atEdge = action == .leftHalf ? abs(current.minX - screen.minX) <= tolerance : abs(current.maxX - screen.maxX) <= tolerance
            let fullHeight = abs(current.minY - screen.minY) <= tolerance && abs(current.height - screen.height) <= tolerance
            let index = atEdge && fullHeight ? fractions.firstIndex { abs(current.width - screen.width * $0) <= tolerance } : nil
            let width = screen.width * fractions[((index ?? -1) + 1) % fractions.count]
            rect = CGRect(x: action == .leftHalf ? screen.minX : screen.maxX - width, y: screen.minY, width: width, height: screen.height)
        case .topHalf: rect = CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: halfHeight)
        case .bottomHalf: rect = CGRect(x: screen.minX, y: screen.minY + halfHeight, width: screen.width, height: halfHeight)
        case .topLeft: rect = CGRect(x: screen.minX, y: screen.minY, width: halfWidth, height: halfHeight)
        case .topRight: rect = CGRect(x: screen.minX + halfWidth, y: screen.minY, width: halfWidth, height: halfHeight)
        case .bottomLeft: rect = CGRect(x: screen.minX, y: screen.minY + halfHeight, width: halfWidth, height: halfHeight)
        case .bottomRight: rect = CGRect(x: screen.minX + halfWidth, y: screen.minY + halfHeight, width: halfWidth, height: halfHeight)
        case .maximize: rect = screen
        case .center:
            let width = min(current.width, screen.width)
            let height = min(current.height, screen.height)
            rect = CGRect(x: screen.midX - width / 2, y: screen.midY - height / 2, width: width, height: height)
        }
        return rounded(rect)
    }

    static func move(_ current: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        let scaleX = target.width / source.width
        let scaleY = target.height / source.height
        return rounded(
            CGRect(
                x: target.minX + (current.minX - source.minX) * scaleX, y: target.minY + (current.minY - source.minY) * scaleY,
                width: current.width * scaleX, height: current.height * scaleY))
    }

    static func stripColumns(count: Int, tile: CGFloat, spacing: CGFloat, available: CGFloat) -> Int {
        max(1, min(9, count, Int((available + spacing) / (tile + spacing))))
    }

    // Centers the panel and quick nav as one group, sliding left so quick nav always fits on the right.
    static func panelX(current: CGFloat?, width: CGFloat, quickNavWidth: CGFloat, spacing: CGFloat, area: CGRect) -> CGFloat {
        let group = width + spacing + quickNavWidth
        return min(current ?? area.midX - group / 2, area.maxX - group)
    }

    private static func rounded(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX.rounded(), y: rect.minY.rounded(), width: rect.width.rounded(), height: rect.height.rounded())
    }
}
