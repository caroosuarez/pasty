import Foundation

@MainActor
final class LoginItemManager {
    private let label = "com.carosuarez.pasty"

    private var plistURL: URL {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        return directory.appendingPathComponent("\(label).plist")
    }

    func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            disable()
        }
    }

    private func enable() throws {
        let launchAgentsDirectory = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": launchArguments(),
            "RunAtLoad": true,
            "KeepAlive": false
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    private func disable() {
        try? FileManager.default.removeItem(at: plistURL)
    }

    private func launchArguments() -> [String] {
        let bundlePath = Bundle.main.bundleURL.path
        if Bundle.main.bundleURL.pathExtension.lowercased() == "app" {
            return ["/usr/bin/open", bundlePath]
        }

        if let executablePath = Bundle.main.executableURL?.path {
            return [executablePath]
        }

        return [CommandLine.arguments[0]]
    }
}
