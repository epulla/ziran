import Foundation

@MainActor
enum Settings {
    static var defaults = UserDefaults.standard
    static let fontSizeRange = 11.0...28.0
    static let defaultFontSize = 14.0
    static var fontSize: Double {
        get { let value = defaults.double(forKey: "fontSize"); return value == 0 ? defaultFontSize : min(max(value, fontSizeRange.lowerBound), fontSizeRange.upperBound) }
        set { defaults.set(min(max(newValue, fontSizeRange.lowerBound), fontSizeRange.upperBound), forKey: "fontSize") }
    }
}
