import Foundation
import Testing
@testable import Ziran

@MainActor @Test func sizesDefaultAndClamp() {
    Settings.defaults = UserDefaults(suiteName: "ZiranTests")!
    Settings.defaults.removePersistentDomain(forName: "ZiranTests")
    #expect(Settings.fontSize == 14)
    Settings.fontSize = 5
    #expect(Settings.fontSize == 11)
    Settings.fontSize = 40
    #expect(Settings.fontSize == 28)
    Settings.fontSize = 20
    #expect(Settings.fontSize == 20)
    #expect(Settings.iconSize == 96)
    Settings.iconSize = 10
    #expect(Settings.iconSize == 48)
    Settings.iconSize = 500
    #expect(Settings.iconSize == 160)
    Settings.iconSize = 120
    #expect(Settings.iconSize == 120)
    Settings.defaults.removePersistentDomain(forName: "ZiranTests")
    Settings.defaults = .standard
}

@MainActor @Test func quickNavKeepsOrderAndDropsMissingFiles() {
    Settings.defaults = UserDefaults(suiteName: "ZiranTests")!
    Settings.defaults.removePersistentDomain(forName: "ZiranTests")
    #expect(Settings.quickNav.isEmpty)
    let folder = FileManager.default.temporaryDirectory
    let web = URL(string: "https://github.com/epulla/ziran")!
    let missing = folder.appendingPathComponent("ziran-missing-\(UUID().uuidString)")
    Settings.quickNav = [web, missing, folder]
    #expect(Settings.quickNav == [web, folder])
    Settings.defaults.removePersistentDomain(forName: "ZiranTests")
    Settings.defaults = .standard
}

@MainActor @Test func windowShortcutsDefaultOnAndPersist() {
    Settings.defaults = UserDefaults(suiteName: "ZiranTests")!
    Settings.defaults.removePersistentDomain(forName: "ZiranTests")
    #expect(Settings.windowShortcuts)
    Settings.windowShortcuts = false
    #expect(!Settings.windowShortcuts)
    Settings.defaults.removePersistentDomain(forName: "ZiranTests")
    Settings.defaults = .standard
}

@MainActor @Test func layoutTemplatesRoundTrip() {
    Settings.defaults = UserDefaults(suiteName: "ZiranTests")!
    Settings.defaults.removePersistentDomain(forName: "ZiranTests")
    let templates = [
        LayoutTemplate(
            name: "Work",
            slots: [
                .init(bundleID: "com.example.editor", action: .leftHalf),
                .init(bundleID: "com.example.browser", action: .rightHalf),
            ])
    ]
    Settings.layoutTemplates = templates
    #expect(Settings.layoutTemplates == templates)
    Settings.defaults.removePersistentDomain(forName: "ZiranTests")
    Settings.defaults = .standard
}
