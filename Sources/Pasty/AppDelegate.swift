import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private lazy var clipboardStore = ClipboardStore(settings: settings)
    private var statusBarController: StatusBarController?
    private var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBarController = StatusBarController(store: clipboardStore, settings: settings)
        self.statusBarController = statusBarController

        clipboardStore.start()

        let hotKeyManager = HotKeyManager()
        hotKeyManager.onHotKeyPressed = { [weak statusBarController] in
            statusBarController?.toggleClipboardWindow()
        }
        hotKeyManager.registerDefaultShortcut()
        self.hotKeyManager = hotKeyManager
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardStore.stop()
        hotKeyManager?.unregister()
    }
}
