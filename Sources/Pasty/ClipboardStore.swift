import AppKit
import CryptoKit
import Foundation

enum ClipboardContent: Equatable {
    case text(String)
    case image(data: Data, width: Int, height: Int)
}

enum ClipboardFilterScope {
    case all
    case text
    case images
}

struct ClipboardItem: Equatable {
    let content: ClipboardContent
    let fingerprint: String
    let createdAt: Date
    let sourceAppBundleIdentifier: String?
    let sourceAppName: String?
}

private struct PersistedClipboardItem: Codable {
    let kind: String
    let text: String?
    let imageData: Data?
    let width: Int?
    let height: Int?
    let fingerprint: String
    let createdAt: Date
    let sourceAppBundleIdentifier: String?
    let sourceAppName: String?
}

@MainActor
final class ClipboardStore: NSObject {
    private let settings: AppSettings
    private let pasteboard = NSPasteboard.general
    private let sourceTypeCandidates: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType("org.nspasteboard.source"),
        NSPasteboard.PasteboardType("com.apple.pasteboard.source"),
        NSPasteboard.PasteboardType("com.apple.cocoa.pasteboard.source")
    ]

    private var timer: Timer?
    private var lastChangeCount: Int
    private var suppressedFingerprint: String?
    private var activePollingInterval: Double
    private var changeObservers: [UUID: () -> Void] = [:]

    private(set) var items: [ClipboardItem] = []

    init(settings: AppSettings) {
        self.settings = settings
        self.lastChangeCount = pasteboard.changeCount
        self.activePollingInterval = settings.pollingInterval
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: AppSettings.didChangeNotification,
            object: settings
        )

        items = loadItemsFromDisk()
        applyRetentionPolicy()
        applyHistoryLimit()
        prunePinnedFingerprints()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func addChangeObserver(_ observer: @escaping () -> Void) -> UUID {
        let token = UUID()
        changeObservers[token] = observer
        return token
    }

    func removeChangeObserver(_ token: UUID) {
        changeObservers.removeValue(forKey: token)
    }

    func orderedItems() -> [ClipboardItem] {
        let pinnedSet = settings.pinnedFingerprints
        let pinnedItems = items.filter { pinnedSet.contains($0.fingerprint) }
        let regularItems = items.filter { !pinnedSet.contains($0.fingerprint) }
        return pinnedItems + regularItems
    }

    func filteredItems(query: String, scope: ClipboardFilterScope) -> [ClipboardItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return orderedItems().filter { item in
            guard itemMatchesScope(item, scope: scope) else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            return itemMatchesQuery(item, query: normalizedQuery)
        }
    }

    func isPinned(_ item: ClipboardItem) -> Bool {
        settings.pinnedFingerprints.contains(item.fingerprint)
    }

    func togglePinned(_ item: ClipboardItem) {
        var pinned = settings.pinnedFingerprints
        if pinned.contains(item.fingerprint) {
            pinned.remove(item.fingerprint)
        } else {
            pinned.insert(item.fingerprint)
        }
        settings.pinnedFingerprints = pinned
    }

    func start() {
        guard timer == nil else { return }
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func clear() {
        items.removeAll { !isPinned($0) }
        prunePinnedFingerprints()
        notifyChange(saveToDisk: true)
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.clearContents()

        let copied: Bool
        switch item.content {
        case .text(let value):
            copied = pasteboard.setString(value, forType: .string)
        case .image(let data, _, _):
            if let image = NSImage(data: data) {
                copied = pasteboard.writeObjects([image])
            } else {
                copied = false
            }
        }

        suppressedFingerprint = copied ? item.fingerprint : nil
    }

    private func startTimer() {
        activePollingInterval = settings.pollingInterval
        timer = Timer(timeInterval: activePollingInterval, target: self, selector: #selector(handleTimerTick), userInfo: nil, repeats: true)

        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func restartTimerIfNeeded() {
        guard timer != nil, settings.pollingInterval != activePollingInterval else { return }
        stop()
        startTimer()
    }

    @objc
    private func handleTimerTick() {
        let previousCount = items.count
        applyRetentionPolicy()
        if items.count != previousCount {
            notifyChange(saveToDisk: true)
        }

        pollPasteboard()
    }

    @objc
    private func settingsDidChange() {
        restartTimerIfNeeded()

        let oldItems = items
        applyRetentionPolicy()
        applyHistoryLimit()
        prunePinnedFingerprints()

        if items != oldItems {
            notifyChange(saveToDisk: true)
            return
        }

        notifyChange(saveToDisk: false)
    }

    private func itemMatchesScope(_ item: ClipboardItem, scope: ClipboardFilterScope) -> Bool {
        switch scope {
        case .all:
            return true
        case .text:
            if case .text = item.content { return true }
            return false
        case .images:
            if case .image = item.content { return true }
            return false
        }
    }

    private func itemMatchesQuery(_ item: ClipboardItem, query: String) -> Bool {
        let source = item.sourceAppName?.lowercased() ?? ""

        switch item.content {
        case .text(let value):
            return value.lowercased().contains(query) || source.contains(query)
        case .image(_, let width, let height):
            let imageDescriptor = "image \(width)x\(height)"
            return imageDescriptor.lowercased().contains(query) || source.contains(query)
        }
    }

    private func notifyChange(saveToDisk: Bool) {
        if saveToDisk {
            saveItemsToDisk()
        }

        for observer in changeObservers.values {
            observer()
        }
    }

    private func applyHistoryLimit() {
        let pinnedSet = settings.pinnedFingerprints
        var regularItems = items.filter { !pinnedSet.contains($0.fingerprint) }
        let pinnedItems = items.filter { pinnedSet.contains($0.fingerprint) }

        if regularItems.count > settings.historyLimit {
            regularItems.removeLast(regularItems.count - settings.historyLimit)
        }

        items = pinnedItems + regularItems
    }

    private func applyRetentionPolicy() {
        let pinnedSet = settings.pinnedFingerprints
        let retentionInterval = TimeInterval(settings.retentionDays) * 24 * 60 * 60
        let cutoff = Date().addingTimeInterval(-retentionInterval)

        items.removeAll { item in
            if pinnedSet.contains(item.fingerprint) {
                return false
            }
            return item.createdAt < cutoff
        }
    }

    private func prunePinnedFingerprints() {
        let validFingerprints = Set(items.map { $0.fingerprint })
        let pruned = settings.pinnedFingerprints.intersection(validFingerprints)
        if pruned != settings.pinnedFingerprints {
            settings.pinnedFingerprints = pruned
        }
    }

    private func pollPasteboard() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard let item = makeClipboardItem() else { return }

        if suppressedFingerprint == item.fingerprint {
            suppressedFingerprint = nil
            return
        }

        if let existingIndex = items.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
            items.remove(at: existingIndex)
        }

        items.insert(item, at: 0)
        applyRetentionPolicy()
        applyHistoryLimit()

        notifyChange(saveToDisk: true)
    }

    private func makeClipboardItem() -> ClipboardItem? {
        let sourceInfo = sourceApplicationInfo()

        if let textValue = pasteboard.string(forType: .string) {
            let normalized: String
            if settings.trimWhitespace {
                normalized = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                normalized = textValue
            }

            if !normalized.isEmpty {
                return ClipboardItem(
                    content: .text(normalized),
                    fingerprint: "text:\(normalized)",
                    createdAt: Date(),
                    sourceAppBundleIdentifier: sourceInfo.bundleIdentifier,
                    sourceAppName: sourceInfo.name
                )
            }
        }

        guard settings.captureImages else {
            return nil
        }

        if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            let (width, height) = imageDimensions(from: imageData)
            return ClipboardItem(
                content: .image(data: imageData, width: width, height: height),
                fingerprint: "image:\(imageHash(for: imageData))",
                createdAt: Date(),
                sourceAppBundleIdentifier: sourceInfo.bundleIdentifier,
                sourceAppName: sourceInfo.name
            )
        }

        return nil
    }

    private func sourceApplicationInfo() -> (bundleIdentifier: String?, name: String?) {
        var bundleIdentifier: String?

        for type in sourceTypeCandidates {
            if let value = pasteboard.string(forType: type), !value.isEmpty {
                bundleIdentifier = value
                break
            }

            if let value = pasteboard.propertyList(forType: type) as? String, !value.isEmpty {
                bundleIdentifier = value
                break
            }
        }

        if bundleIdentifier == nil {
            bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }

        if let bundleIdentifier,
           let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return (bundleIdentifier, runningApp.localizedName)
        }

        if let bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let name = appURL.deletingPathExtension().lastPathComponent
            return (bundleIdentifier, name)
        }

        return (bundleIdentifier, nil)
    }

    private func imageDimensions(from data: Data) -> (Int, Int) {
        guard let image = NSImage(data: data) else { return (0, 0) }
        return (Int(image.size.width.rounded()), Int(image.size.height.rounded()))
    }

    private func imageHash(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
    }

    private func historyFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("Pasty", isDirectory: true)
        return directory.appendingPathComponent("history.json")
    }

    private func loadItemsFromDisk() -> [ClipboardItem] {
        let url = historyFileURL()
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let persistedItems = try? JSONDecoder().decode([PersistedClipboardItem].self, from: data) else { return [] }

        return persistedItems.compactMap { persisted in
            let content: ClipboardContent

            switch persisted.kind {
            case "text":
                guard let text = persisted.text else { return nil }
                content = .text(text)
            case "image":
                guard let imageData = persisted.imageData,
                      let width = persisted.width,
                      let height = persisted.height else { return nil }
                content = .image(data: imageData, width: width, height: height)
            default:
                return nil
            }

            return ClipboardItem(
                content: content,
                fingerprint: persisted.fingerprint,
                createdAt: persisted.createdAt,
                sourceAppBundleIdentifier: persisted.sourceAppBundleIdentifier,
                sourceAppName: persisted.sourceAppName
            )
        }
    }

    private func saveItemsToDisk() {
        let persistedItems: [PersistedClipboardItem] = items.map { item in
            switch item.content {
            case .text(let text):
                return PersistedClipboardItem(
                    kind: "text",
                    text: text,
                    imageData: nil,
                    width: nil,
                    height: nil,
                    fingerprint: item.fingerprint,
                    createdAt: item.createdAt,
                    sourceAppBundleIdentifier: item.sourceAppBundleIdentifier,
                    sourceAppName: item.sourceAppName
                )
            case .image(let data, let width, let height):
                return PersistedClipboardItem(
                    kind: "image",
                    text: nil,
                    imageData: data,
                    width: width,
                    height: height,
                    fingerprint: item.fingerprint,
                    createdAt: item.createdAt,
                    sourceAppBundleIdentifier: item.sourceAppBundleIdentifier,
                    sourceAppName: item.sourceAppName
                )
            }
        }

        guard let data = try? JSONEncoder().encode(persistedItems) else { return }

        let fileURL = historyFileURL()
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
