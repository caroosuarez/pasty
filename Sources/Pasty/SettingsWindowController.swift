import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settings: AppSettings
    private let loginItemManager = LoginItemManager()

    private let historyValueLabel = NSTextField(labelWithString: "")
    private let menuItemsValueLabel = NSTextField(labelWithString: "")
    private let pollingValueLabel = NSTextField(labelWithString: "")
    private let retentionValueLabel = NSTextField(labelWithString: "")

    private lazy var historySlider: NSSlider = {
        let slider = NSSlider(value: Double(settings.historyLimit), minValue: 10, maxValue: 500, target: self, action: #selector(historyChanged(_:)))
        slider.numberOfTickMarks = 50
        slider.allowsTickMarkValuesOnly = false
        return slider
    }()

    private lazy var menuItemsSlider: NSSlider = {
        let slider = NSSlider(value: Double(settings.menuItemLimit), minValue: 5, maxValue: 100, target: self, action: #selector(menuItemsChanged(_:)))
        slider.numberOfTickMarks = 20
        slider.allowsTickMarkValuesOnly = false
        return slider
    }()

    private lazy var pollingSlider: NSSlider = {
        let slider = NSSlider(value: settings.pollingInterval, minValue: 0.2, maxValue: 2.0, target: self, action: #selector(pollingChanged(_:)))
        slider.numberOfTickMarks = 19
        slider.allowsTickMarkValuesOnly = false
        return slider
    }()

    private lazy var retentionSlider: NSSlider = {
        let slider = NSSlider(value: Double(settings.retentionDays), minValue: 1, maxValue: 365, target: self, action: #selector(retentionChanged(_:)))
        slider.numberOfTickMarks = 13
        slider.allowsTickMarkValuesOnly = false
        return slider
    }()

    private lazy var captureImagesCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "Capture images", target: self, action: #selector(captureImagesChanged(_:)))
        checkbox.state = settings.captureImages ? .on : .off
        return checkbox
    }()

    private lazy var trimWhitespaceCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "Trim whitespace in text entries", target: self, action: #selector(trimWhitespaceChanged(_:)))
        checkbox.state = settings.trimWhitespace ? .on : .off
        return checkbox
    }()

    private lazy var launchAtLoginCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(launchAtLoginChanged(_:)))
        checkbox.state = loginItemManager.isEnabled() ? .on : .off
        return checkbox
    }()

    init(settings: AppSettings) {
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 410),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pasty Settings"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        buildUI()
        refreshLabels()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        launchAtLoginCheckbox.state = loginItemManager.isEnabled() ? .on : .off
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.alignment = .leading
        root.translatesAutoresizingMaskIntoConstraints = false

        root.addArrangedSubview(makeSliderRow(title: "History size", slider: historySlider, valueLabel: historyValueLabel))
        root.addArrangedSubview(makeSliderRow(title: "Menu items shown", slider: menuItemsSlider, valueLabel: menuItemsValueLabel))
        root.addArrangedSubview(makeSliderRow(title: "Polling interval", slider: pollingSlider, valueLabel: pollingValueLabel))
        root.addArrangedSubview(makeSliderRow(title: "Keep history for", slider: retentionSlider, valueLabel: retentionValueLabel))
        root.addArrangedSubview(captureImagesCheckbox)
        root.addArrangedSubview(trimWhitespaceCheckbox)
        root.addArrangedSubview(launchAtLoginCheckbox)

        let noteLabel = NSTextField(labelWithString: "Default retention is 7 days. Pinned items are not auto-removed.")
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.lineBreakMode = .byWordWrapping
        noteLabel.maximumNumberOfLines = 2
        root.addArrangedSubview(noteLabel)

        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20)
        ])
    }

    private func makeSliderRow(title: String, slider: NSSlider, valueLabel: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.alignment = .right
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let topRow = NSStackView(views: [titleLabel, valueLabel])
        topRow.orientation = .horizontal
        topRow.distribution = .fillProportionally

        let row = NSStackView(views: [topRow, slider])
        row.orientation = .vertical
        row.spacing = 6
        return row
    }

    private func refreshLabels() {
        historyValueLabel.stringValue = "\(settings.historyLimit)"
        menuItemsValueLabel.stringValue = "\(settings.menuItemLimit)"
        pollingValueLabel.stringValue = String(format: "%.1fs", settings.pollingInterval)
        retentionValueLabel.stringValue = "\(settings.retentionDays) days"
    }

    @objc private func historyChanged(_ sender: NSSlider) {
        let newValue = Int(sender.doubleValue.rounded())
        settings.historyLimit = newValue
        historySlider.doubleValue = Double(settings.historyLimit)
        refreshLabels()
    }

    @objc private func menuItemsChanged(_ sender: NSSlider) {
        let newValue = Int(sender.doubleValue.rounded())
        settings.menuItemLimit = newValue
        menuItemsSlider.doubleValue = Double(settings.menuItemLimit)
        refreshLabels()
    }

    @objc private func pollingChanged(_ sender: NSSlider) {
        let rounded = (sender.doubleValue * 10).rounded() / 10
        settings.pollingInterval = rounded
        pollingSlider.doubleValue = settings.pollingInterval
        refreshLabels()
    }

    @objc private func retentionChanged(_ sender: NSSlider) {
        let rounded = Int(sender.doubleValue.rounded())
        settings.retentionDays = rounded
        retentionSlider.doubleValue = Double(settings.retentionDays)
        refreshLabels()
    }

    @objc private func captureImagesChanged(_ sender: NSButton) {
        settings.captureImages = sender.state == .on
    }

    @objc private func trimWhitespaceChanged(_ sender: NSButton) {
        settings.trimWhitespace = sender.state == .on
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        do {
            try loginItemManager.setEnabled(sender.state == .on)
        } catch {
            sender.state = loginItemManager.isEnabled() ? .on : .off
            showAlert(message: "Could not update launch at login.", info: error.localizedDescription)
        }
    }

    private func showAlert(message: String, info: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = info
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
