import Foundation
import Testing
@testable import Ziran

@MainActor @Test func fontSizeDefaultAndClamp() {
    Settings.defaults = UserDefaults(suiteName: "ZiranTests")!
    Settings.defaults.removePersistentDomain(forName: "ZiranTests")
    #expect(Settings.fontSize == 14)
    Settings.fontSize = 5
    #expect(Settings.fontSize == 11)
    Settings.fontSize = 40
    #expect(Settings.fontSize == 28)
    Settings.fontSize = 20
    #expect(Settings.fontSize == 20)
    Settings.defaults = .standard
}
