import AppKit
import CryptoKit
import Foundation

enum ClipboardContent: Equatable {
    case text(String)
    case image(data: Data, width: Int, height: Int)
}

struct ClipboardItem: Equatable {
    let content: ClipboardContent
    let fingerprint: String
    let createdAt: Date
}

@MainActor
final class ClipboardStore: NSObject {
    private let settings: AppSettings
    private let pasteboard = NSPasteboard.general

    private var timer: Timer?
    private var lastChangeCount: Int
    private var suppressedFingerprint: String?

    private(set) var items: [ClipboardItem] = []
    var onChange: (() -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
        self.lastChangeCount = pasteboard.changeCount
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: AppSettings.didChangeNotification,
            object: settings
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
        items.removeAll()
        onChange?()
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
        timer = Timer(timeInterval: settings.pollingInterval, target: self, selector: #selector(handleTimerTick), userInfo: nil, repeats: true)

        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @objc
    private func handleTimerTick() {
        pollPasteboard()
    }

    @objc
    private func settingsDidChange() {
        if items.count > settings.historyLimit {
            items.removeLast(items.count - settings.historyLimit)
            onChange?()
        }

        if timer != nil {
            stop()
            startTimer()
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

        if items.count > settings.historyLimit {
            items.removeLast(items.count - settings.historyLimit)
        }

        onChange?()
    }

    private func makeClipboardItem() -> ClipboardItem? {
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
                    createdAt: Date()
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
                createdAt: Date()
            )
        }

        return nil
    }

    private func imageDimensions(from data: Data) -> (Int, Int) {
        guard let image = NSImage(data: data) else { return (0, 0) }
        return (Int(image.size.width.rounded()), Int(image.size.height.rounded()))
    }

    private func imageHash(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
    }
}
