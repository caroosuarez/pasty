import AppKit
import Foundation

@MainActor
final class StatusBarController: NSObject {
    private let store: ClipboardStore
    private let settings: AppSettings
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let settingsWindowController: SettingsWindowController
    private let browserWindowController: ClipboardBrowserWindowController

    init(store: ClipboardStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.settingsWindowController = SettingsWindowController(settings: settings)
        self.browserWindowController = ClipboardBrowserWindowController(store: store)
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: AppSettings.didChangeNotification,
            object: settings
        )

        _ = store.addChangeObserver { [weak self] in
            self?.rebuildMenu()
        }

        configureStatusItem()
        rebuildMenu()
    }

    func toggleClipboardWindow() {
        browserWindowController.toggleVisibility()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            if let symbolImage = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pasty") {
                symbolImage.isTemplate = true
                button.image = symbolImage
            } else {
                button.title = "Pasty"
            }

            button.toolTip = "Pasty"
        }

        statusItem.menu = menu
    }

    @objc
    private func settingsDidChange() {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let recentItems = Array(store.orderedItems().prefix(settings.menuItemLimit))

        if recentItems.isEmpty {
            let emptyItem = NSMenuItem(title: "Clipboard is empty", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for item in recentItems {
                let menuItem = NSMenuItem(
                    title: displayTitle(for: item),
                    action: #selector(selectClipboardItem(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = item

                if case .image = item.content {
                    menuItem.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")
                }

                menu.addItem(menuItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let showClipboardItem = NSMenuItem(title: "Show Clipboard", action: #selector(openClipboardWindow), keyEquivalent: "v")
        showClipboardItem.keyEquivalentModifierMask = [.command, .shift]
        showClipboardItem.target = self
        menu.addItem(showClipboardItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        let clearItem = NSMenuItem(title: "Clear History (Keep Pinned)", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        let quitItem = NSMenuItem(title: "Quit Pasty", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func selectClipboardItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        store.copyToPasteboard(item)
    }

    @objc private func openClipboardWindow() {
        browserWindowController.present()
    }

    @objc private func openSettings() {
        settingsWindowController.present()
    }

    @objc private func clearHistory() {
        store.clear()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func displayTitle(for item: ClipboardItem) -> String {
        let pinPrefix = store.isPinned(item) ? "★ " : ""

        switch item.content {
        case .text(let value):
            let compact = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

            if compact.count <= 66 {
                return pinPrefix + compact
            }

            return pinPrefix + String(compact.prefix(63)) + "..."
        case .image(_, let width, let height):
            if width > 0 && height > 0 {
                return pinPrefix + "Image \(width)x\(height)"
            }
            return pinPrefix + "Image"
        }
    }
}
