import CoreGraphics

struct WindowInfo: Equatable, Sendable {
    let id: CGWindowID
    let pid: pid_t
    let bundleId: String
    let appName: String
    let title: String
    let isMinimized: Bool
}
