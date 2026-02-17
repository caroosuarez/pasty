import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private lazy var clipboardStore = ClipboardStore(settings: settings)
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(store: clipboardStore, settings: settings)
        clipboardStore.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardStore.stop()
    }
}
