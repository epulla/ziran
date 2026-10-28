import AppKit
import Testing

@testable import Ziran

@MainActor @Test func menuBarIconIsEighteenPointTemplateWithRetinaRepresentation() throws {
    let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Resources").standardized
    let bundle = try #require(Bundle(url: resources))
    let icon = try #require(AppDelegate.menuBarIcon(in: bundle))
    #expect(icon.isTemplate)
    #expect(icon.size == NSSize(width: 18, height: 18))
    #expect(Set(icon.representations.map(\.pixelsWide)) == [18, 36])
}

@MainActor @Test func menuBarIconIsNilWithoutResources() {
    #expect(AppDelegate.menuBarIcon(in: Bundle(for: NSObject.self)) == nil)
}
