import Foundation

@MainActor
final class AppSettings {
    static let didChangeNotification = Notification.Name("PastySettingsDidChange")

    private enum Key {
        static let historyLimit = "historyLimit"
        static let menuItemLimit = "menuItemLimit"
        static let captureImages = "captureImages"
        static let trimWhitespace = "trimWhitespace"
        static let pollingInterval = "pollingInterval"
        static let pinnedFingerprints = "pinnedFingerprints"
        static let retentionDays = "retentionDays"
    }

    private let defaults = UserDefaults.standard

    var historyLimit: Int {
        didSet {
            historyLimit = Self.clamp(historyLimit, min: 10, max: 500)
            defaults.set(historyLimit, forKey: Key.historyLimit)
            postChange()
        }
    }

    var menuItemLimit: Int {
        didSet {
            menuItemLimit = Self.clamp(menuItemLimit, min: 5, max: 100)
            defaults.set(menuItemLimit, forKey: Key.menuItemLimit)
            postChange()
        }
    }

    var captureImages: Bool {
        didSet {
            defaults.set(captureImages, forKey: Key.captureImages)
            postChange()
        }
    }

    var trimWhitespace: Bool {
        didSet {
            defaults.set(trimWhitespace, forKey: Key.trimWhitespace)
            postChange()
        }
    }

    var pollingInterval: Double {
        didSet {
            pollingInterval = Self.clamp(pollingInterval, min: 0.2, max: 2.0)
            defaults.set(pollingInterval, forKey: Key.pollingInterval)
            postChange()
        }
    }

    var pinnedFingerprints: Set<String> {
        didSet {
            defaults.set(Array(pinnedFingerprints), forKey: Key.pinnedFingerprints)
            postChange()
        }
    }

    var retentionDays: Int {
        didSet {
            retentionDays = Self.clamp(retentionDays, min: 1, max: 365)
            defaults.set(retentionDays, forKey: Key.retentionDays)
            postChange()
        }
    }

    init() {
        let defaultHistoryLimit = 50
        let defaultMenuItemLimit = 20
        let defaultCaptureImages = true
        let defaultTrimWhitespace = true
        let defaultPollingInterval = 0.5
        let defaultPinnedFingerprints: [String] = []
        let defaultRetentionDays = 7

        if defaults.object(forKey: Key.historyLimit) == nil {
            defaults.set(defaultHistoryLimit, forKey: Key.historyLimit)
        }

        if defaults.object(forKey: Key.menuItemLimit) == nil {
            defaults.set(defaultMenuItemLimit, forKey: Key.menuItemLimit)
        }

        if defaults.object(forKey: Key.captureImages) == nil {
            defaults.set(defaultCaptureImages, forKey: Key.captureImages)
        }

        if defaults.object(forKey: Key.trimWhitespace) == nil {
            defaults.set(defaultTrimWhitespace, forKey: Key.trimWhitespace)
        }

        if defaults.object(forKey: Key.pollingInterval) == nil {
            defaults.set(defaultPollingInterval, forKey: Key.pollingInterval)
        }

        if defaults.object(forKey: Key.pinnedFingerprints) == nil {
            defaults.set(defaultPinnedFingerprints, forKey: Key.pinnedFingerprints)
        }

        if defaults.object(forKey: Key.retentionDays) == nil {
            defaults.set(defaultRetentionDays, forKey: Key.retentionDays)
        }

        historyLimit = Self.clamp(defaults.integer(forKey: Key.historyLimit), min: 10, max: 500)
        menuItemLimit = Self.clamp(defaults.integer(forKey: Key.menuItemLimit), min: 5, max: 100)
        captureImages = defaults.bool(forKey: Key.captureImages)
        trimWhitespace = defaults.bool(forKey: Key.trimWhitespace)
        pollingInterval = Self.clamp(defaults.double(forKey: Key.pollingInterval), min: 0.2, max: 2.0)
        pinnedFingerprints = Set(defaults.stringArray(forKey: Key.pinnedFingerprints) ?? defaultPinnedFingerprints)
        retentionDays = Self.clamp(defaults.integer(forKey: Key.retentionDays), min: 1, max: 365)
    }

    private static func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
        if value < minValue { return minValue }
        if value > maxValue { return maxValue }
        return value
    }

    private func postChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
