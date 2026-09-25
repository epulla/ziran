import Foundation

@MainActor
enum Settings {
    static var defaults = UserDefaults.standard
    static let fontSizeRange = 11.0...28.0
    static let defaultFontSize = 14.0
    static let iconSizeRange = 48.0...160.0
    static let defaultIconSize = 96.0

    static var fontSize: Double {
        get { value("fontSize", default: defaultFontSize, range: fontSizeRange) }
        set { defaults.set(min(max(newValue, fontSizeRange.lowerBound), fontSizeRange.upperBound), forKey: "fontSize") }
    }

    static var iconSize: Double {
        get { value("iconSize", default: defaultIconSize, range: iconSizeRange) }
        set { defaults.set(min(max(newValue, iconSizeRange.lowerBound), iconSizeRange.upperBound), forKey: "iconSize") }
    }

    private static func value(_ key: String, default fallback: Double, range: ClosedRange<Double>) -> Double {
        let value = defaults.double(forKey: key)
        return value == 0 ? fallback : min(max(value, range.lowerBound), range.upperBound)
    }
}
