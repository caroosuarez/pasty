import AppKit
import Foundation

private final class FloatingClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private enum BrowserCollection: Int, CaseIterable {
    case clipboard
    case links
    case notes
    case images
    case pinned

    var title: String {
        switch self {
        case .clipboard:
            return "Clipboard"
        case .links:
            return "Useful Links"
        case .notes:
            return "Important Notes"
        case .images:
            return "Images"
        case .pinned:
            return "Pinned"
        }
    }
}

private enum ClipboardCardTheme {
    case blue
    case green
    case amber
    case rose

    var backgroundColor: NSColor {
        switch self {
        case .blue:
            return NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.95, alpha: 1)
        case .green:
            return NSColor(calibratedRed: 0.18, green: 0.72, blue: 0.42, alpha: 1)
        case .amber:
            return NSColor(calibratedRed: 0.96, green: 0.72, blue: 0.23, alpha: 1)
        case .rose:
            return NSColor(calibratedRed: 0.94, green: 0.24, blue: 0.44, alpha: 1)
        }
    }

    var cardFillColor: NSColor {
        let darkened = backgroundColor.blended(withFraction: 0.35, of: .black) ?? backgroundColor
        return darkened.withAlphaComponent(0.86)
    }
}

private enum AppAccent {
    case solid(NSColor)
    case gradient(NSColor, NSColor)
}

private final class TruncatingTextView: NSView {
    var text: String = "" {
        didSet {
            needsDisplay = true
        }
    }

    var textColor: NSColor = NSColor.white.withAlphaComponent(0.98) {
        didSet {
            needsDisplay = true
        }
    }

    var font: NSFont = NSFont.systemFont(ofSize: 14, weight: .semibold) {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        attributed.draw(
            with: bounds,
            options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine]
        )
    }
}

private final class ClipboardCardItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("ClipboardCardItem")

    private let cardView = NSVisualEffectView()
    private let dimOverlayView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let ageLabel = NSTextField(labelWithString: "")
    private let contentView = TruncatingTextView()
    private let sourceStripView = NSView()
    private let sourceStripGradientLayer = CAGradientLayer()
    private let sourceLabel = NSTextField(labelWithString: "")
    private let sourceIconView = NSImageView()
    private let previewImageView = NSImageView()
    private lazy var contentBottomToCardConstraint = contentView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10)
    private lazy var contentBottomToPreviewConstraint = contentView.bottomAnchor.constraint(equalTo: previewImageView.topAnchor, constant: -8)
    private lazy var previewHeightConstraint = previewImageView.heightAnchor.constraint(equalToConstant: 54)
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false
    var onDoubleClick: (() -> Void)?
    private lazy var cardDoubleClickGesture: NSClickGestureRecognizer = {
        let gesture = NSClickGestureRecognizer(target: self, action: #selector(handleCardDoubleClick(_:)))
        gesture.numberOfClicksRequired = 2
        gesture.buttonMask = 0x1
        return gesture
    }()

    override var isSelected: Bool {
        didSet {
            updateVisualState(animated: true)
        }
    }

    override func loadView() {
        view = NSView()
        view.addGestureRecognizer(cardDoubleClickGesture)

        cardView.material = .menu
        cardView.state = .active
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 16
        cardView.layer?.masksToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false

        dimOverlayView.wantsLayer = true
        dimOverlayView.translatesAutoresizingMaskIntoConstraints = false

        sourceStripView.wantsLayer = true
        sourceStripView.translatesAutoresizingMaskIntoConstraints = false
        sourceStripGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        sourceStripGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        sourceStripGradientLayer.isHidden = true
        sourceStripView.layer?.addSublayer(sourceStripGradientLayer)

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        ageLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        ageLabel.textColor = NSColor.white.withAlphaComponent(0.92)
        ageLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.translatesAutoresizingMaskIntoConstraints = false

        sourceLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        sourceLabel.textColor = NSColor.white.withAlphaComponent(0.95)
        sourceLabel.lineBreakMode = .byTruncatingTail
        sourceLabel.alignment = .right
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false

        sourceIconView.imageScaling = .scaleProportionallyUpOrDown
        sourceIconView.wantsLayer = true
        sourceIconView.layer?.cornerRadius = 6
        sourceIconView.layer?.masksToBounds = true
        sourceIconView.translatesAutoresizingMaskIntoConstraints = false

        previewImageView.imageScaling = .scaleAxesIndependently
        previewImageView.wantsLayer = true
        previewImageView.layer?.cornerRadius = 10
        previewImageView.layer?.masksToBounds = true
        previewImageView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(cardView)
        cardView.addSubview(dimOverlayView)
        cardView.addSubview(sourceStripView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(ageLabel)
        cardView.addSubview(sourceLabel)
        cardView.addSubview(sourceIconView)
        cardView.addSubview(contentView)
        cardView.addSubview(previewImageView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: view.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            dimOverlayView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            dimOverlayView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            dimOverlayView.topAnchor.constraint(equalTo: cardView.topAnchor),
            dimOverlayView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            sourceStripView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            sourceStripView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            sourceStripView.topAnchor.constraint(equalTo: cardView.topAnchor),
            sourceStripView.heightAnchor.constraint(equalToConstant: 34),

            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: sourceStripView.centerYAnchor),

            ageLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            ageLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            sourceIconView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            sourceIconView.centerYAnchor.constraint(equalTo: sourceStripView.centerYAnchor),
            sourceIconView.widthAnchor.constraint(equalToConstant: 18),
            sourceIconView.heightAnchor.constraint(equalToConstant: 18),

            contentView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            contentView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            contentView.topAnchor.constraint(equalTo: sourceStripView.bottomAnchor, constant: 12),
            contentBottomToCardConstraint,

            previewImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            previewImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            previewImageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10),
            previewHeightConstraint,

            sourceLabel.leadingAnchor.constraint(greaterThanOrEqualTo: ageLabel.trailingAnchor, constant: 8),
            sourceLabel.trailingAnchor.constraint(equalTo: sourceIconView.leadingAnchor, constant: -6),
            sourceLabel.centerYAnchor.constraint(equalTo: sourceStripView.centerYAnchor)
        ])

        updateVisualState(animated: false)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        sourceStripGradientLayer.frame = sourceStripView.bounds
        refreshHoverTrackingArea()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onDoubleClick = nil
        isHovered = false
        updateVisualState(animated: false)
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isHovered else { return }
        isHovered = true
        updateVisualState(animated: true)
        runHoverWobble()
    }

    override func mouseExited(with event: NSEvent) {
        guard isHovered else { return }
        isHovered = false
        updateVisualState(animated: true)
    }
    
    
    @objc
    private func handleCardDoubleClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onDoubleClick?()
    }

    func configure(type: String, age: String, content: String, source: String, sourceIcon: NSImage?, preview: NSImage?, theme: ClipboardCardTheme, sourceStripAccent: AppAccent, isPinned: Bool) {
        titleLabel.stringValue = isPinned ? "★ \(type)" : type
        ageLabel.stringValue = age
        contentView.text = content
        sourceLabel.stringValue = source
        sourceIconView.image = sourceIcon

        let hasPreview = preview != nil
        previewImageView.image = preview
        previewImageView.isHidden = !hasPreview
        previewHeightConstraint.constant = hasPreview ? 54 : 0
        contentBottomToCardConstraint.isActive = !hasPreview
        contentBottomToPreviewConstraint.isActive = hasPreview

        cardView.layer?.backgroundColor = theme.cardFillColor.cgColor
        applySourceStripAccent(sourceStripAccent)

        updateVisualState(animated: false)
    }

    private func applySourceStripAccent(_ accent: AppAccent) {
        switch accent {
        case .solid(let color):
            let muted = color.blended(withFraction: 0.45, of: .white) ?? color
            sourceStripGradientLayer.isHidden = true
            sourceStripView.layer?.backgroundColor = muted.withAlphaComponent(0.78).cgColor

        case .gradient(let first, let second):
            let mutedFirst = first.blended(withFraction: 0.35, of: .white) ?? first
            let mutedSecond = second.blended(withFraction: 0.35, of: .white) ?? second
            sourceStripView.layer?.backgroundColor = NSColor.clear.cgColor
            sourceStripGradientLayer.colors = [
                mutedFirst.withAlphaComponent(0.82).cgColor,
                mutedSecond.withAlphaComponent(0.82).cgColor
            ]
            sourceStripGradientLayer.locations = [0, 1]
            sourceStripGradientLayer.isHidden = false
            sourceStripGradientLayer.frame = sourceStripView.bounds
        }
    }

    private func refreshHoverTrackingArea() {
        if let hoverTrackingArea {
            view.removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    private func runHoverWobble() {
        guard let layer = cardView.layer else { return }

        let wobble = CAKeyframeAnimation(keyPath: "transform.translation.x")
        wobble.values = [0, -1.6, 1.2, -0.8, 0.5, 0]
        wobble.keyTimes = [0, 0.16, 0.34, 0.56, 0.78, 1]
        wobble.duration = 0.18
        wobble.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(wobble, forKey: "hoverWobble")
    }

    private func updateVisualState(animated: Bool) {
        guard let layer = cardView.layer else { return }

        let overlayAlpha: CGFloat = isHovered ? 0.24 : 0.18
        let borderWidth: CGFloat
        let borderColor: CGColor?

        if isSelected {
            borderWidth = 2.5
            borderColor = NSColor.white.withAlphaComponent(0.96).cgColor
        } else if isHovered {
            borderWidth = 1.25
            borderColor = NSColor.white.withAlphaComponent(0.52).cgColor
        } else {
            borderWidth = 0
            borderColor = nil
        }

        let transform = isHovered ? CATransform3DMakeScale(1.01, 1.01, 1) : CATransform3DIdentity

        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        if animated {
            CATransaction.setAnimationDuration(0.12)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        }

        dimOverlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(overlayAlpha).cgColor
        layer.borderWidth = borderWidth
        layer.borderColor = borderColor
        layer.transform = transform

        CATransaction.commit()
    }
}
@MainActor
final class ClipboardBrowserWindowController: NSWindowController, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout, NSSearchFieldDelegate, NSWindowDelegate {
    private let store: ClipboardStore

    private var localEventMonitor: Any?
    private var localMouseMonitor: Any?
    private var displayedItems: [ClipboardItem] = []
    private var iconCache: [String: NSImage] = [:]
    private var accentCache: [String: AppAccent] = [:]

    private let searchField = NSSearchField()
    private let collectionTabs = NSSegmentedControl(labels: BrowserCollection.allCases.map { $0.title }, trackingMode: .selectOne, target: nil, action: nil)
    private let collectionView = NSCollectionView()
    private let pinButton = NSButton(title: "Pin", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    init(store: ClipboardStore) {
        self.store = store

        let frame = NSRect(x: 0, y: 0, width: 1120, height: 290)
        let panel = FloatingClipboardPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.title = "Pasty"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        super.init(window: panel)

        window?.delegate = self

        buildUI()
        refreshDisplayedItems(keepSelection: false)

        _ = store.addChangeObserver { [weak self] in
            self?.refreshDisplayedItems(keepSelection: true)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        refreshDisplayedItems(keepSelection: false, defaultSelectionScrollPosition: .left)
        positionWindowAtBottom()
        showWindow(nil)
        window?.orderFrontRegardless()
        window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleLocalKeyEvent(event) ?? event
            }
        }

        if localMouseMonitor == nil {
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.handleLocalMouseEvent(event) ?? event
            }
        }

        window?.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            self.window?.animator().alphaValue = 1
        }

        window?.makeFirstResponder(searchField)
    }

    func toggleVisibility() {
        if window?.isVisible == true {
            close()
            return
        }

        present()
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    func windowWillClose(_ notification: Notification) {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    private func positionWindowAtBottom() {
        guard let window else { return }

        let targetScreen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen else { return }

        let visibleFrame = targetScreen.visibleFrame
        let desiredWidth = min(visibleFrame.width - 90, 1120)
        let desiredHeight: CGFloat = 290
        let x = visibleFrame.midX - (desiredWidth / 2)
        let y = visibleFrame.minY + 18

        window.setFrame(NSRect(x: x, y: y, width: desiredWidth, height: desiredHeight), display: true)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let chromeView = NSVisualEffectView()
        chromeView.material = .underWindowBackground
        chromeView.blendingMode = .withinWindow
        chromeView.state = .active
        chromeView.wantsLayer = true
        chromeView.layer?.cornerRadius = 20
        chromeView.layer?.masksToBounds = true
        chromeView.translatesAutoresizingMaskIntoConstraints = false

        let borderView = NSView()
        borderView.wantsLayer = true
        borderView.layer?.cornerRadius = 20
        borderView.layer?.borderWidth = 1
        borderView.layer?.borderColor = NSColor.white.withAlphaComponent(0.35).cgColor
        borderView.translatesAutoresizingMaskIntoConstraints = false

        searchField.placeholderString = "Search"
        searchField.controlSize = .small
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.delegate = self

        collectionTabs.selectedSegment = 0
        collectionTabs.segmentStyle = .capsule
        collectionTabs.target = self
        collectionTabs.action = #selector(collectionChanged)

        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.sectionInset = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        layout.itemSize = NSSize(width: 210, height: 168)

        collectionView.collectionViewLayout = layout
        collectionView.register(ClipboardCardItem.self, forItemWithIdentifier: ClipboardCardItem.identifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]

        let collectionScroll = NSScrollView()
        collectionScroll.drawsBackground = false
        collectionScroll.borderType = .noBorder
        collectionScroll.hasHorizontalScroller = true
        collectionScroll.hasVerticalScroller = false
        collectionScroll.documentView = collectionView
        collectionScroll.translatesAutoresizingMaskIntoConstraints = false

        pinButton.bezelStyle = .rounded
        pinButton.controlSize = .small
        pinButton.target = self
        pinButton.action = #selector(togglePin)

        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .small
        copyButton.target = self
        copyButton.action = #selector(copySelected)

        let topRow = NSStackView(views: [searchField, collectionTabs])
        topRow.orientation = .horizontal
        topRow.spacing = 10

        let bottomRow = NSStackView(views: [pinButton, copyButton])
        bottomRow.orientation = .horizontal
        bottomRow.alignment = .centerY
        bottomRow.spacing = 8

        let root = NSStackView(views: [topRow, collectionScroll, bottomRow])
        root.orientation = .vertical
        root.spacing = 10
        root.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(chromeView)
        contentView.addSubview(borderView)
        chromeView.addSubview(root)

        NSLayoutConstraint.activate([
            chromeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chromeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            chromeView.topAnchor.constraint(equalTo: contentView.topAnchor),
            chromeView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            borderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            borderView.topAnchor.constraint(equalTo: contentView.topAnchor),
            borderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            root.leadingAnchor.constraint(equalTo: chromeView.leadingAnchor, constant: 14),
            root.trailingAnchor.constraint(equalTo: chromeView.trailingAnchor, constant: -14),
            root.topAnchor.constraint(equalTo: chromeView.topAnchor, constant: 12),
            root.bottomAnchor.constraint(equalTo: chromeView.bottomAnchor, constant: -10),

            collectionScroll.heightAnchor.constraint(equalToConstant: 188),
            searchField.widthAnchor.constraint(equalToConstant: 210)
        ])

        updateActionButtons()
    }

    private func handleLocalKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard window?.isKeyWindow == true else { return event }

        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let char = event.charactersIgnoringModifiers?.lowercased()

        if keyCode == 53 {
            close()
            return nil
        }

        if keyCode == 36 || keyCode == 76 {
            copySelected(nil)
            return nil
        }

        if keyCode == 123 {
            moveSelection(delta: -1)
            return nil
        }

        if keyCode == 124 {
            moveSelection(delta: 1)
            return nil
        }

        if modifiers == [.command], char == "f" {
            window?.makeFirstResponder(searchField)
            return nil
        }

        if modifiers == [.command], char == "p" {
            togglePin(nil)
            return nil
        }

        return event
    }

    private func handleLocalMouseEvent(_ event: NSEvent) -> NSEvent? {
        guard window?.isKeyWindow == true else { return event }
        guard event.clickCount >= 2 else { return event }

        let locationInCollection = collectionView.convert(event.locationInWindow, from: nil)
        guard let indexPath = collectionView.indexPathForItem(at: locationInCollection),
              indexPath.item >= 0,
              indexPath.item < displayedItems.count else {
            return event
        }

        let item = displayedItems[indexPath.item]
        selectIndex(indexPath.item, scrollPosition: [])
        store.copyToPasteboard(item)
        close()
        return nil
    }

    private func moveSelection(delta: Int) {
        guard !displayedItems.isEmpty else { return }

        let current = selectedIndex ?? 0
        let next = max(0, min(displayedItems.count - 1, current + delta))
        selectIndex(next)
    }

    private var selectedIndex: Int? {
        collectionView.selectionIndexPaths.first?.item
    }

    private var selectedItem: ClipboardItem? {
        guard let selectedIndex, selectedIndex >= 0, selectedIndex < displayedItems.count else { return nil }
        return displayedItems[selectedIndex]
    }

    private func selectIndex(_ index: Int, scrollPosition: NSCollectionView.ScrollPosition = .centeredHorizontally) {
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.selectItems(at: [indexPath], scrollPosition: scrollPosition)
        updateActionButtons()
    }

    @objc
    private func searchChanged() {
        refreshDisplayedItems(keepSelection: false)
    }

    @objc
    private func collectionChanged() {
        refreshDisplayedItems(keepSelection: false)
    }

    
    @objc
    private func copySelected(_ sender: Any?) {
        guard let item = selectedItem else { return }
        store.copyToPasteboard(item)
        close()
    }

    @objc
    private func togglePin(_ sender: Any?) {
        guard let item = selectedItem else { return }
        store.togglePinned(item)
        refreshDisplayedItems(keepSelection: true)
    }

    private func currentCollection() -> BrowserCollection {
        BrowserCollection(rawValue: collectionTabs.selectedSegment) ?? .clipboard
    }

    private func refreshDisplayedItems(keepSelection: Bool, defaultSelectionScrollPosition: NSCollectionView.ScrollPosition = .centeredHorizontally) {
        let previousFingerprint = keepSelection ? selectedItem?.fingerprint : nil
        displayedItems = filteredItemsForCurrentCollection(query: searchField.stringValue)

        collectionView.reloadData()

        if let previousFingerprint,
           let index = displayedItems.firstIndex(where: { $0.fingerprint == previousFingerprint }) {
            selectIndex(index)
        } else if !displayedItems.isEmpty {
            selectIndex(0, scrollPosition: defaultSelectionScrollPosition)
        } else {
            collectionView.deselectAll(nil)
            updateActionButtons()
        }
    }

    private func filteredItemsForCurrentCollection(query: String) -> [ClipboardItem] {
        switch currentCollection() {
        case .clipboard:
            return store.filteredItems(query: query, scope: .all)
        case .links:
            return store.filteredItems(query: query, scope: .text).filter { isLink(item: $0) }
        case .notes:
            return store.filteredItems(query: query, scope: .text).filter { !isLink(item: $0) }
        case .images:
            return store.filteredItems(query: query, scope: .images)
        case .pinned:
            return store.filteredItems(query: query, scope: .all).filter { store.isPinned($0) }
        }
    }

    private func updateActionButtons() {
        let hasSelection = selectedItem != nil
        pinButton.isEnabled = hasSelection
        copyButton.isEnabled = hasSelection

        if let item = selectedItem {
            pinButton.title = store.isPinned(item) ? "Unpin" : "Pin"
        } else {
            pinButton.title = "Pin"
        }
    }

    private func isLink(item: ClipboardItem) -> Bool {
        guard case .text(let value) = item.content else { return false }
        let lower = value.lowercased()
        return lower.contains("http://") || lower.contains("https://") || lower.contains("www.")
    }

    private func textValue(of item: ClipboardItem) -> String {
        switch item.content {
        case .text(let value):
            return value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        case .image(_, let width, let height):
            if width > 0 && height > 0 {
                return "Image \(width)x\(height)"
            }
            return "Image"
        }
    }

    private func cardTheme(for item: ClipboardItem) -> ClipboardCardTheme {
        switch item.content {
        case .image:
            return .rose
        case .text:
            if isLink(item: item) {
                return .green
            }
            return currentCollection() == .notes ? .amber : .blue
        }
    }

    private func relativeAgeString(for date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }

    private func sourceIcon(for item: ClipboardItem) -> NSImage? {
        guard let bundleIdentifier = item.sourceAppBundleIdentifier else {
            return NSImage(named: NSImage.applicationIconName)
        }

        if let cached = iconCache[bundleIdentifier] {
            return cached
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let image = NSWorkspace.shared.icon(forFile: appURL.path)
            image.size = NSSize(width: 18, height: 18)
            iconCache[bundleIdentifier] = image
            return image
        }

        let fallback = NSImage(named: NSImage.applicationIconName)
        if let fallback {
            fallback.size = NSSize(width: 18, height: 18)
            iconCache[bundleIdentifier] = fallback
        }
        return fallback
    }

    private func sourceName(for item: ClipboardItem) -> String {
        if let source = item.sourceAppName, !source.isEmpty {
            return source
        }

        return "Unknown App"
    }

    private func sourceStripAccent(for item: ClipboardItem, sourceIcon: NSImage?, fallback: NSColor) -> AppAccent {
        let bundleIdentifier = item.sourceAppBundleIdentifier?.lowercased() ?? ""
        let source = sourceName(for: item).lowercased()

        if bundleIdentifier == "company.thebrowser.browser" || bundleIdentifier.contains("arc") || source.contains("arc") {
            return .gradient(
                NSColor(calibratedRed: 0.22, green: 0.55, blue: 0.96, alpha: 1),
                NSColor(calibratedRed: 0.93, green: 0.25, blue: 0.35, alpha: 1)
            )
        }

        if bundleIdentifier == "com.openai.chat" || bundleIdentifier.contains("chatgpt") || source.contains("chatgpt") || source.contains("chat gpt") {
            return .solid(NSColor(calibratedRed: 0.62, green: 0.62, blue: 0.64, alpha: 1))
        }

        let cacheKey = !bundleIdentifier.isEmpty ? bundleIdentifier : source
        if !cacheKey.isEmpty, let cachedAccent = accentCache[cacheKey] {
            return cachedAccent
        }

        let inferredAccent = accentFromIcon(sourceIcon) ?? .solid(fallback.withAlphaComponent(0.95))

        if !cacheKey.isEmpty {
            accentCache[cacheKey] = inferredAccent
        }

        return inferredAccent
    }

    private func accentFromIcon(_ image: NSImage?) -> AppAccent? {
        guard let image else { return nil }
        guard let sample = iconPixelSample(from: image, dimension: 44) else { return nil }

        let binCount = 24
        var binWeight = [CGFloat](repeating: 0, count: binCount)
        var binRed = [CGFloat](repeating: 0, count: binCount)
        var binGreen = [CGFloat](repeating: 0, count: binCount)
        var binBlue = [CGFloat](repeating: 0, count: binCount)
        var binHue = [CGFloat](repeating: 0, count: binCount)

        var neutralWeight: CGFloat = 0
        var neutralRed: CGFloat = 0
        var neutralGreen: CGFloat = 0
        var neutralBlue: CGFloat = 0

        for i in stride(from: 0, to: sample.count, by: 4) {
            let red = CGFloat(sample[i]) / 255
            let green = CGFloat(sample[i + 1]) / 255
            let blue = CGFloat(sample[i + 2]) / 255
            let alpha = CGFloat(sample[i + 3]) / 255

            if alpha < 0.35 { continue }

            let color = NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var componentAlpha: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &componentAlpha)

            if brightness < 0.10 { continue }

            if saturation < 0.16 {
                let weight = alpha * max(0.2, brightness)
                neutralWeight += weight
                neutralRed += red * weight
                neutralGreen += green * weight
                neutralBlue += blue * weight
                continue
            }

            if saturation < 0.24 && brightness > 0.92 { continue }

            let weight = saturation * alpha
            let bin = min(binCount - 1, Int(hue * CGFloat(binCount)))

            binWeight[bin] += weight
            binRed[bin] += red * weight
            binGreen[bin] += green * weight
            binBlue[bin] += blue * weight
            binHue[bin] += hue * weight
        }

        let sortedBins = binWeight.enumerated().sorted { $0.element > $1.element }

        if let first = sortedBins.first, first.element > 0.01 {
            let primaryIndex = first.offset
            let primaryWeight = max(0.0001, binWeight[primaryIndex])
            let primaryHue = binHue[primaryIndex] / primaryWeight
            let primaryColor = tunedAccentColor(
                red: binRed[primaryIndex] / primaryWeight,
                green: binGreen[primaryIndex] / primaryWeight,
                blue: binBlue[primaryIndex] / primaryWeight
            )

            if sortedBins.count > 1 {
                let second = sortedBins[1]
                if second.element > first.element * 0.45 {
                    let secondaryIndex = second.offset
                    let secondaryWeight = max(0.0001, binWeight[secondaryIndex])
                    let secondaryHue = binHue[secondaryIndex] / secondaryWeight
                    if hueDistance(primaryHue, secondaryHue) > 0.12 {
                        let secondaryColor = tunedAccentColor(
                            red: binRed[secondaryIndex] / secondaryWeight,
                            green: binGreen[secondaryIndex] / secondaryWeight,
                            blue: binBlue[secondaryIndex] / secondaryWeight
                        )
                        return .gradient(primaryColor, secondaryColor)
                    }
                }
            }

            return .solid(primaryColor)
        }

        if neutralWeight > 0.01 {
            let neutralColor = NSColor(
                calibratedRed: neutralRed / neutralWeight,
                green: neutralGreen / neutralWeight,
                blue: neutralBlue / neutralWeight,
                alpha: 1
            )
            return .solid(neutralColor)
        }

        return nil
    }

    private func iconPixelSample(from image: NSImage, dimension: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: dimension * dimension * 4)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: dimension,
                height: dimension,
                bitsPerComponent: 8,
                bytesPerRow: dimension * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.setBlendMode(.copy)
        context.interpolationQuality = .high

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(
            in: NSRect(x: 0, y: 0, width: dimension, height: dimension),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        return pixels
    }

    private func tunedAccentColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> NSColor {
        let color = NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        if saturation < 0.12 {
            return color
        }

        return NSColor(
            calibratedHue: hue,
            saturation: min(1, max(0.38, saturation * 1.03)),
            brightness: min(1, max(0.42, brightness * 1.02)),
            alpha: 1
        )
    }

    private func hueDistance(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
        let delta = abs(lhs - rhs)
        return min(delta, 1 - delta)
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedItems.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = displayedItems[indexPath.item]
        let contentText = textValue(of: item)
        let typeLabel: String
        let previewImage: NSImage?

        switch item.content {
        case .text:
            typeLabel = isLink(item: item) ? "Link" : "Text"
            previewImage = nil
        case .image(let data, _, _):
            typeLabel = "Image"
            previewImage = NSImage(data: data)
        }

        let cardItem = collectionView.makeItem(withIdentifier: ClipboardCardItem.identifier, for: indexPath)
        guard let clipboardCardItem = cardItem as? ClipboardCardItem else {
            return cardItem
        }

        let theme = cardTheme(for: item)
        let sourceAppIcon = sourceIcon(for: item)
        let itemFingerprint = item.fingerprint

        clipboardCardItem.onDoubleClick = { [weak self] in
            guard let self,
                  let tappedItem = self.displayedItems.first(where: { $0.fingerprint == itemFingerprint }) else {
                return
            }

            self.store.copyToPasteboard(tappedItem)
            self.close()
        }

        clipboardCardItem.configure(
            type: typeLabel,
            age: relativeAgeString(for: item.createdAt),
            content: contentText,
            source: sourceName(for: item),
            sourceIcon: sourceAppIcon,
            preview: previewImage,
            theme: theme,
            sourceStripAccent: sourceStripAccent(for: item, sourceIcon: sourceAppIcon, fallback: theme.backgroundColor),
            isPinned: store.isPinned(item)
        )

        return clipboardCardItem
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateActionButtons()

        guard let event = NSApp.currentEvent,
              event.clickCount >= 2,
              let indexPath = indexPaths.first,
              indexPath.item >= 0,
              indexPath.item < displayedItems.count else {
            return
        }

        let item = displayedItems[indexPath.item]
        store.copyToPasteboard(item)
        close()
    }
}
