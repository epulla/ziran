import AppKit

@MainActor
final class WindowResizer {
    enum Command: Equatable { case layout(Layout.Action), restore, nextDisplay, previousDisplay }

    private var restoreFrames: [CGWindowID: CGRect] = [:]

    func perform(_ command: Command) {
        guard let window = AX.focusedWindow(), let id = AX.windowID(window), let current = AX.frame(window),
            let primaryMaxY = NSScreen.screens.first?.frame.maxY
        else { return }
        let screens: [(frame: CGRect, visible: CGRect)] = NSScreen.screens
            .map { screen in (frame: AX.flip(screen.frame, primaryMaxY: primaryMaxY), visible: AX.flip(screen.visibleFrame, primaryMaxY: primaryMaxY)) }
            .sorted { left, right in left.frame.minX == right.frame.minX ? left.frame.minY < right.frame.minY : left.frame.minX < right.frame.minX }
        let index = screens.firstIndex { $0.frame.contains(CGPoint(x: current.midX, y: current.midY)) } ?? 0
        let target: CGRect
        switch command {
        case .layout(let action): target = Layout.frame(action, current: current, in: screens[index].visible)
        case .restore:
            guard let saved = restoreFrames.removeValue(forKey: id) else { return }
            AX.setFrame(window, saved)
            return
        case .nextDisplay, .previousDisplay:
            guard screens.count > 1 else { return }
            let next = (index + (command == .nextDisplay ? 1 : screens.count - 1)) % screens.count
            target = Layout.move(current, from: screens[index].visible, to: screens[next].visible)
        }
        if restoreFrames[id] == nil { restoreFrames[id] = current }
        AX.setFrame(window, target)
    }
}
