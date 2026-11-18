import AppKit
import Quartz

/// 全局蓝白主题配色（清新淡蓝），集中定义便于统一调整。
private enum MSTheme {
    /// 界面主蓝（图标、强调文字、分段控件）
    static let accent = NSColor(red: 0.20, green: 0.53, blue: 0.92, alpha: 1)
    /// 选中行渐变的浅色端
    static let selectLight = NSColor(red: 0.42, green: 0.68, blue: 0.97, alpha: 1)
    /// 选中行渐变的深色端
    static let selectDeep = NSColor(red: 0.16, green: 0.45, blue: 0.86, alpha: 1)
    /// 选中态投影
    static let selectShadow = NSColor(red: 0.12, green: 0.34, blue: 0.62, alpha: 0.20)
    /// 背景底部光晕
    static let glow = CGColor(red: 0.38, green: 0.62, blue: 0.95, alpha: 0.24)
    /// 选中行里的关键词高亮（暖白，淡蓝底上醒目）
    static let selectKeyword = NSColor(red: 1.0, green: 0.97, blue: 0.82, alpha: 1)
}

// MARK: - Panel & views

final class MSPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class MSGradientView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let base = NSGradient(colors: [
            NSColor(red: 0.87, green: 0.94, blue: 1.00, alpha: 1),
            NSColor(red: 0.94, green: 0.97, blue: 1.00, alpha: 1),
            NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1)
        ])
        base?.draw(in: bounds, angle: 270)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let space = CGColorSpaceCreateDeviceRGB()

        let topGlow = CGGradient(colorsSpace: space,
                                 colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.72),
                                          CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                                 locations: [0, 1])
        let bottomGlow = CGGradient(colorsSpace: space,
                                    colors: [MSTheme.glow,
                                             CGColor(red: 0.38, green: 0.62, blue: 0.95, alpha: 0)] as CFArray,
                                    locations: [0, 1])

        context.saveGState()
        if let gradient = topGlow {
            let center = CGPoint(x: bounds.width * 0.16, y: bounds.height * 0.96)
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: 460, options: [])
        }
        if let gradient = bottomGlow {
            let center = CGPoint(x: bounds.width * 0.92, y: bounds.height * 0.04)
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: 380, options: [])
        }
        context.restoreGState()
    }
}

private class MSCardView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        appearance = NSAppearance(named: .aqua)
        material = .popover
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.62).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.08
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 8
    }
    required init?(coder: NSCoder) { fatalError() }
}

private final class MSToolbarBackground: MSCardView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = 16
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.32).cgColor
    }
    required init?(coder: NSCoder) { fatalError() }
}

private final class MSLineView: NSView {
    var color: NSColor
    override init(frame frameRect: NSRect) {
        self.color = NSColor.black.withAlphaComponent(0.09)
        super.init(frame: frameRect)
    }
    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) {
        self.color = NSColor.black.withAlphaComponent(0.09)
        super.init(coder: coder)
    }
    override func draw(_ dirtyRect: NSRect) {
        color.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: 0.5))
        path.line(to: NSPoint(x: bounds.width, y: 0.5))
        path.lineWidth = 1
        path.stroke()
    }
}

private final class MSResultRowView: NSTableRowView {
    override func drawBackground(in dirtyRect: NSRect) {
        guard !isSelected else { return }
        let rect = bounds.insetBy(dx: 4, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        NSColor.white.withAlphaComponent(0.16).setFill()
        path.fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let rect = bounds.insetBy(dx: 4, dy: 2)

        // 轻微投影，让选中项从列表中浮起
        let shadowRect = rect.offsetBy(dx: 0, dy: -1)
        MSTheme.selectShadow.setFill()
        NSBezierPath(roundedRect: shadowRect, xRadius: 10, yRadius: 10).fill()

        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)

        // 与界面呼应的清新淡蓝渐变
        let gradient = NSGradient(colors: [
            MSTheme.selectLight,
            MSTheme.selectDeep
        ])
        gradient?.draw(in: path, angle: 270)

        // 顶部柔光高光
        let topHighlight = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.22),
            NSColor.white.withAlphaComponent(0)
        ])
        let highlightRect = NSRect(x: rect.minX + 1, y: rect.midY, width: rect.width - 2, height: rect.height / 2 - 1)
        topHighlight?.draw(in: NSBezierPath(roundedRect: highlightRect, xRadius: 9, yRadius: 9), angle: 270)

        // 白色内描边提亮
        NSColor.white.withAlphaComponent(0.55).setStroke()
        path.lineWidth = 1
        path.stroke()

        // 左侧圆角指示条，强化"当前选中"的视觉锚点
        let barHeight = rect.height - 20
        let bar = NSBezierPath(roundedRect: NSRect(x: rect.minX + 4, y: rect.minY + 10, width: 3.5, height: barHeight),
                               xRadius: 1.75, yRadius: 1.75)
        NSColor.white.withAlphaComponent(0.95).setFill()
        bar.fill()
    }
}

private final class MSResultCell: NSTableCellView {
    let iconBackdrop = NSView()
    let fileImageView = NSImageView()
    let nameField = NSTextField(labelWithString: "")
    let detailField = NSTextField(labelWithString: "")
    let badge = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconBackdrop.translatesAutoresizingMaskIntoConstraints = false
        iconBackdrop.wantsLayer = true
        iconBackdrop.layer?.cornerRadius = 9

        fileImageView.translatesAutoresizingMaskIntoConstraints = false
        fileImageView.imageScaling = .scaleProportionallyUpOrDown

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        nameField.lineBreakMode = .byTruncatingTail

        detailField.translatesAutoresizingMaskIntoConstraints = false
        detailField.font = NSFont.systemFont(ofSize: 10)
        detailField.textColor = .secondaryLabelColor
        detailField.lineBreakMode = .byTruncatingTail

        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.font = NSFont.systemFont(ofSize: 9, weight: .semibold)
        badge.alignment = .center
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 5

        addSubview(iconBackdrop)
        addSubview(fileImageView)
        addSubview(nameField)
        addSubview(detailField)
        addSubview(badge)

        NSLayoutConstraint.activate([
            iconBackdrop.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconBackdrop.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBackdrop.widthAnchor.constraint(equalToConstant: 40),
            iconBackdrop.heightAnchor.constraint(equalToConstant: 40),

            fileImageView.centerXAnchor.constraint(equalTo: iconBackdrop.centerXAnchor),
            fileImageView.centerYAnchor.constraint(equalTo: iconBackdrop.centerYAnchor),
            fileImageView.widthAnchor.constraint(equalToConstant: 34),
            fileImageView.heightAnchor.constraint(equalToConstant: 34),

            nameField.leadingAnchor.constraint(equalTo: iconBackdrop.trailingAnchor, constant: 10),
            nameField.trailingAnchor.constraint(equalTo: badge.leadingAnchor, constant: -6),
            nameField.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            detailField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
            detailField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            detailField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 3),

            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            badge.centerYAnchor.constraint(equalTo: nameField.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 38),
            badge.heightAnchor.constraint(equalToConstant: 17)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

private final class MSToolbarItem: NSView {
    let button = NSButton()
    let label = NSTextField(labelWithString: "")

    init(icon: String, title: String, tag: Int, target: AnyObject?) {
        super.init(frame: .zero)
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        if let symbol = NSImage(systemSymbolName: icon, accessibilityDescription: title) {
            button.image = symbol.withSymbolConfiguration(config)
        }
        button.contentTintColor = MSTheme.accent
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.target = target
        button.action = #selector(MSPanelController.toolbarAction(_:))
        button.tag = tag
        button.translatesAutoresizingMaskIntoConstraints = false

        label.stringValue = title
        label.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(button)
        addSubview(label)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 28),
            label.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 2),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

private final class MSEmptyStateView: NSView {
    let iconView = NSImageView()
    let titleField = NSTextField(labelWithString: "")
    let subtitleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let config = NSImage.SymbolConfiguration(pointSize: 34, weight: .light)
        iconView.image = NSImage(systemSymbolName: "magnifyingglass.circle", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        iconView.contentTintColor = MSTheme.accent.withAlphaComponent(0.55)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleField.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleField.alignment = .center
        titleField.textColor = .labelColor
        titleField.translatesAutoresizingMaskIntoConstraints = false

        subtitleField.font = NSFont.systemFont(ofSize: 11)
        subtitleField.alignment = .center
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.maximumNumberOfLines = 2
        subtitleField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleField)
        addSubview(subtitleField)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -26),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
            titleField.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            subtitleField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 4),
            subtitleField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            subtitleField.trailingAnchor.constraint(equalTo: titleField.trailingAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Main controller

final class MSPanelController: NSObject, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {

    let panel: MSPanel
    private var results: [MSFileResult] = []
    private var selected: MSFileResult?
    private var currentQuery = ""
    private var searchStartDate: Date?

    private let segmented = NSSegmentedControl(labels: ["文件名", "内容"], trackingMode: .selectOne, target: nil, action: #selector(modeChanged(_:)))
    private let searchField = NSSearchField(frame: .zero)
    private let statusLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let emptyView = MSEmptyStateView(frame: .zero)
    private let previewContainer = MSCardView(frame: .zero)
    private let previewIcon = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let kindLabel = NSTextField(labelWithString: "")
    private var infoRows: [NSTextField] = []
    private var quickLookView: QLPreviewView?
    private var debounce: DispatchWorkItem?
    private var localKeyMonitor: Any?

    /// 左侧结果卡片：只有在空状态时才把点击转成“聚焦搜索框”，有结果时交还表格选择。
    private let leftCard = MSCardView(frame: .zero)
    private lazy var leftCardClick: NSClickGestureRecognizer = {
        let gesture = NSClickGestureRecognizer(target: self, action: #selector(focusSearchFromResults))
        gesture.numberOfClicksRequired = 1
        return gesture
    }()

    private let panelWidth: CGFloat = 960
    private let panelHeight: CGFloat = 620

    override init() {
        panel = MSPanel(contentRect: NSRect(x: 0, y: 0, width: 960, height: 620),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        super.init()
        panel.title = "MacroSeek"
        panel.appearance = NSAppearance(named: .aqua)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.maxSize = NSSize(width: panelWidth, height: panelHeight)
        panel.minSize = NSSize(width: panelWidth, height: panelHeight)

        let root = MSGradientView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        root.wantsLayer = true
        root.layer?.cornerRadius = 20
        root.layer?.masksToBounds = true
        root.layer?.borderWidth = 1
        root.layer?.borderColor = NSColor.white.withAlphaComponent(0.65).cgColor
        panel.contentView = root

        buildTopBar(in: root)
        buildBody(in: root)
        buildToolbar(in: root)

        segmented.selectedSegment = 0
        segmented.target = self
        searchField.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(openSelected)

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel, event.keyCode == 53 else { return event }
            self.hide()
            return nil
        }
        updateEmptyState()
    }

    deinit {
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
    }

    // MARK: - Layout

    private func buildTopBar(in root: NSView) {
        let barHeight: CGFloat = 72
        let bar = NSView(frame: NSRect(x: 0, y: panelHeight - barHeight, width: panelWidth, height: barHeight))
        root.addSubview(bar)

        if let icon = Bundle.main.image(forResource: "AppIcon") {
            let iconView = NSImageView(frame: NSRect(x: 20, y: 22, width: 28, height: 28))
            iconView.image = icon
            iconView.imageScaling = .scaleProportionallyUpOrDown
            bar.addSubview(iconView)
        }

        segmented.frame = NSRect(x: 58, y: 22, width: 148, height: 28)
        segmented.segmentStyle = .rounded
        segmented.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        if #available(macOS 10.15, *) {
            segmented.selectedSegmentBezelColor = MSTheme.accent
        }
        bar.addSubview(segmented)

        searchField.frame = NSRect(x: 220, y: 18, width: panelWidth - 244, height: 36)
        searchField.placeholderString = "搜索文件名或文件内容…"
        searchField.font = NSFont.systemFont(ofSize: 16)
        searchField.bezelStyle = .roundedBezel
        bar.addSubview(searchField)

        statusLabel.frame = NSRect(x: 220, y: 4, width: panelWidth - 244, height: 14)
        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.alignment = .right
        statusLabel.textColor = .secondaryLabelColor
        bar.addSubview(statusLabel)

        let line = MSLineView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 1))
        bar.addSubview(line)
    }

    private func buildBody(in root: NSView) {
        let bodyBottom: CGFloat = 100
        let bodyTop: CGFloat = panelHeight - 80
        let bodyHeight = bodyTop - bodyBottom

        let leftFrame = NSRect(x: 18, y: bodyBottom, width: 340, height: bodyHeight)
        leftCard.frame = leftFrame
        root.addSubview(leftCard)
        leftCard.addGestureRecognizer(leftCardClick)

        let leftTitle = NSTextField(labelWithString: "搜索结果")
        leftTitle.frame = NSRect(x: 14, y: bodyHeight - 28, width: 200, height: 18)
        leftTitle.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        leftTitle.textColor = .secondaryLabelColor
        leftCard.addSubview(leftTitle)

        let scrollFrame = NSRect(x: 8, y: 10, width: leftFrame.width - 16, height: bodyHeight - 46)
        scrollView.frame = scrollFrame
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        tableView.frame = NSRect(x: 0, y: 0, width: scrollFrame.width, height: scrollFrame.height)
        tableView.rowHeight = 62
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = []
        tableView.selectionHighlightStyle = .regular
        tableView.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Main"))
        column.width = scrollFrame.width
        tableView.addTableColumn(column)
        scrollView.documentView = tableView
        leftCard.addSubview(scrollView)

        emptyView.frame = scrollFrame
        emptyView.addGestureRecognizer(NSClickGestureRecognizer(target: self,
                                                                action: #selector(focusSearchFromResults)))
        leftCard.addSubview(emptyView)

        let rightX: CGFloat = 372
        let rightFrame = NSRect(x: rightX, y: bodyBottom, width: panelWidth - rightX - 18, height: bodyHeight)
        let rightCard = MSCardView(frame: rightFrame)
        root.addSubview(rightCard)
        let rightWidth = rightFrame.width

        let rightTitle = NSTextField(labelWithString: "文件预览")
        rightTitle.frame = NSRect(x: 16, y: bodyHeight - 28, width: 200, height: 18)
        rightTitle.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        rightTitle.textColor = .secondaryLabelColor
        rightCard.addSubview(rightTitle)

        nameLabel.frame = NSRect(x: 16, y: bodyHeight - 66, width: rightWidth - 32, height: 28)
        nameLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingMiddle
        rightCard.addSubview(nameLabel)

        kindLabel.frame = NSRect(x: 16, y: bodyHeight - 88, width: rightWidth - 32, height: 16)
        kindLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        kindLabel.alignment = .center
        kindLabel.textColor = .secondaryLabelColor
        rightCard.addSubview(kindLabel)

        previewContainer.frame = NSRect(x: 14, y: 150, width: rightWidth - 28, height: bodyHeight - 150 - 104)
        previewContainer.layer?.cornerRadius = 12
        rightCard.addSubview(previewContainer)

        previewIcon.frame = NSRect(x: (previewContainer.frame.width - 112) / 2,
                                   y: (previewContainer.frame.height - 112) / 2,
                                   width: 112, height: 112)
        previewIcon.imageScaling = .scaleProportionallyUpOrDown
        previewIcon.isHidden = true
        previewContainer.addSubview(previewIcon)

        let infoHeader = NSTextField(labelWithString: "文件信息")
        infoHeader.frame = NSRect(x: 16, y: 132, width: 100, height: 14)
        infoHeader.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        infoHeader.textColor = .tertiaryLabelColor
        rightCard.addSubview(infoHeader)

        let rowH: CGFloat = 21
        let rowWidth = rightWidth - 32
        let titles = ["文件路径", "创建时间", "修改时间", "文件大小", "文件格式", "内容匹配"]
        for (index, title) in titles.enumerated() {
            let y = 106 - CGFloat(index) * rowH
            let titleField = NSTextField(labelWithString: title)
            titleField.frame = NSRect(x: 16, y: y, width: 62, height: rowH)
            titleField.font = NSFont.systemFont(ofSize: 10)
            titleField.textColor = .secondaryLabelColor
            rightCard.addSubview(titleField)

            let value = NSTextField(labelWithString: "—")
            value.frame = NSRect(x: 82, y: y, width: rowWidth - 66, height: rowH)
            value.font = NSFont.systemFont(ofSize: 10)
            value.alignment = .right
            value.lineBreakMode = .byTruncatingMiddle
            value.textColor = .labelColor
            rightCard.addSubview(value)
            infoRows.append(value)

            let separator = MSLineView(frame: NSRect(x: 16, y: y, width: rowWidth, height: 1))
            separator.color = NSColor.black.withAlphaComponent(0.07)
            rightCard.addSubview(separator)
        }
        updatePreview()
    }

    private func buildToolbar(in root: NSView) {
        let bar = MSToolbarBackground(frame: NSRect(x: 18, y: 14, width: panelWidth - 36, height: 70))
        root.addSubview(bar)

        let items: [(String, String, Int)] = [
            ("folder", "打开", 0),
            ("doc.on.doc", "复制", 1),
            ("magnifyingglass", "访达显示", 2),
            ("link", "复制路径", 3),
            ("folder.badge.minus", "移动到", 4),
            ("folder.badge.plus", "复制到", 5),
            ("airplayaudio", "隔空投送", 6),
            ("info.circle", "显示简介", 7)
        ]
        let itemWidth = bar.frame.width / CGFloat(items.count)
        for (index, item) in items.enumerated() {
            let view = MSToolbarItem(icon: item.0, title: item.1, tag: item.2, target: self)
            view.frame = NSRect(x: CGFloat(index) * itemWidth, y: 4, width: itemWidth, height: 62)
            bar.addSubview(view)

            if index == 1 || index == 3 || index == 5 {
                let separator = NSView(frame: NSRect(x: CGFloat(index + 1) * itemWidth - 0.5, y: 16, width: 1, height: 38))
                separator.wantsLayer = true
                separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.42).cgColor
                bar.addSubview(separator)
            }
        }
    }

    // MARK: - Window

    func show() {
        // 弹出位置：鼠标所在屏幕的可视区域正中（避开菜单栏与 Dock），多屏时跟随鼠标更自然。
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = area.midX - panelWidth / 2
        let y = area.midY - panelHeight / 2
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        searchField.window?.makeFirstResponder(searchField)
        MSSearchEngine.shared.refreshVolumes(clearCache: false)
    }

    func hide() {
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func refreshSearch() { performSearch() }
    func contains(_ point: NSPoint) -> Bool { panel.frame.contains(point) }

    /// 空结果区点击 → 直接把键盘焦点交给搜索框，用户无需先点顶部输入框。
    @objc private func focusSearchFromResults() {
        guard results.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
        MSLogger.log("左侧空结果区点击，已聚焦搜索框")
    }

    // MARK: - Search

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        MSLogger.log("切换搜索模式:", sender.label(forSegment: sender.selectedSegment) ?? "")
        performSearch()
    }

    func controlTextDidChange(_ obj: Notification) {
        debounce?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.performSearch() }
        debounce = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
    }

    private func performSearch() {
        let query = searchField.stringValue
        currentQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            selected = nil
            statusLabel.stringValue = ""
            tableView.reloadData()
            updatePreview()
            updateEmptyState()
            return
        }

        searchStartDate = Date()
        statusLabel.stringValue = "搜索中…"
        let mode: MSSearchMode = segmented.selectedSegment == 0 ? .name : .content

        MSSearchEngine.shared.search(query: query, mode: mode) { [weak self] items, finished in
            guard let self else { return }
            self.results = items

            var targetIndex: Int?
            if let selectedURL = self.selected?.url {
                targetIndex = items.firstIndex { $0.url == selectedURL }
            }
            if targetIndex == nil, !items.isEmpty { targetIndex = 0 }

            // 先重载数据，再设置选中：避免 reloadData 把选中态清掉。
            self.tableView.reloadData()
            if let index = targetIndex {
                self.selected = items[index]
                self.tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            } else {
                self.selected = nil
            }
            self.refreshVisibleCells()
            self.updatePreview()
            self.updateEmptyState()

            let elapsed = self.searchStartDate.map { String(format: "%.2f", Date().timeIntervalSince($0)) } ?? "0.00"
            self.statusLabel.stringValue = finished
                ? "\(items.count) 个结果 · \(elapsed)s"
                : "\(items.count) 个结果 · 搜索中…"
        }
    }

    private func updateEmptyState() {
        let isEmpty = results.isEmpty
        leftCardClick.isEnabled = isEmpty
        emptyView.isHidden = !isEmpty
        guard isEmpty else { return }
        let hasQuery = !currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        emptyView.titleField.stringValue = hasQuery ? "没有找到匹配项" : "输入关键词开始搜索"
        emptyView.subtitleField.stringValue = hasQuery
            ? "换个关键词，或切换到“内容”模式再试"
            : "支持文件名与文件内容检索\n网络硬盘中的文件也会被搜索"
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        MSResultRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = results[row]
        let cell = MSResultCell(frame: NSRect(x: 0, y: 0, width: tableView.frame.width, height: 62))
        cell.imageView = nil
        applyCellStyle(cell, item: item, selected: tableView.selectedRow == row)
        return cell
    }

    /// 把一行的内容/颜色样式套用到 cell。viewFor 与选中态刷新共用，避免用 reloadData 重建选中行。
    private func applyCellStyle(_ cell: MSResultCell, item: MSFileResult, selected: Bool) {
        cell.fileImageView.image = NSWorkspace.shared.icon(forFile: item.url.path)

        let ext = item.isDirectory ? "文件夹" : item.url.pathExtension.uppercased()
        if ext == "文件夹" || ext.isEmpty {
            cell.badge.isHidden = true
        } else {
            cell.badge.isHidden = false
            cell.badge.stringValue = String(ext.prefix(4))
            cell.badge.textColor = selected ? .white : badgeTextColor(for: ext)
            cell.badge.layer?.backgroundColor = (selected
                ? NSColor.white.withAlphaComponent(0.22)
                : badgeBackgroundColor(for: ext)).cgColor
        }

        cell.iconBackdrop.layer?.backgroundColor = (selected
            ? NSColor.white.withAlphaComponent(0.22)
            : badgeBackgroundColor(for: ext)).cgColor

        cell.nameField.attributedStringValue = attributedName(item.name, selected: selected)
        cell.detailField.stringValue = item.matchedSnippet ?? item.url.path
        cell.detailField.textColor = selected ? NSColor.white.withAlphaComponent(0.78) : .secondaryLabelColor
    }

    /// 仅重绘可见行的样式以反映最新选中态，不调用 reloadData（否则会清掉选中态导致高亮失效）。
    private func refreshVisibleCells() {
        let range = tableView.rows(in: tableView.visibleRect)
        for row in range.lowerBound..<range.upperBound where row >= 0 && row < results.count {
            guard let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? MSResultCell else { continue }
            applyCellStyle(cell, item: results[row], selected: tableView.selectedRow == row)
        }
    }

    private func attributedName(_ text: String, selected: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        let full = NSRange(text.startIndex..<text.endIndex, in: text)
        result.addAttributes([
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: selected ? NSColor.white : NSColor.labelColor
        ], range: full)

        let needle = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !needle.isEmpty, let range = text.range(of: needle, options: .caseInsensitive) {
            result.addAttributes([
                .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: selected
                    ? MSTheme.selectKeyword  // 暖白关键词，淡蓝背景上醒目
                    : MSTheme.accent
            ], range: NSRange(range, in: text))
        }
        return result
    }

    private func badgeBackgroundColor(for ext: String) -> NSColor {
        switch ext.lowercased() {
        case "pdf": return NSColor.systemRed.withAlphaComponent(0.14)
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "tiff": return NSColor.systemGreen.withAlphaComponent(0.14)
        case "doc", "docx", "pages", "rtf": return NSColor.systemBlue.withAlphaComponent(0.14)
        case "xls", "xlsx", "csv", "numbers": return NSColor.systemTeal.withAlphaComponent(0.14)
        case "zip", "rar", "7z", "tar", "gz": return NSColor.systemOrange.withAlphaComponent(0.14)
        default: return MSTheme.accent.withAlphaComponent(0.12)
        }
    }

    private func badgeTextColor(for ext: String) -> NSColor {
        switch ext.lowercased() {
        case "pdf": return .systemRed
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "tiff": return .systemGreen
        case "doc", "docx", "pages", "rtf": return .systemBlue
        case "xls", "xlsx", "csv", "numbers": return .systemTeal
        case "zip", "rar", "7z", "tar", "gz": return .systemOrange
        default: return MSTheme.accent
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        selected = row >= 0 && row < results.count ? results[row] : nil
        refreshVisibleCells()
        updatePreview()
    }

    // MARK: - Preview & info

    private func updatePreview() {
        guard let item = selected else {
            nameLabel.stringValue = ""
            kindLabel.stringValue = ""
            infoRows.forEach { $0.stringValue = "—" }
            quickLookView?.isHidden = true
            previewIcon.isHidden = true
            return
        }

        nameLabel.stringValue = item.name
        kindLabel.stringValue = item.isDirectory ? "文件夹" : (item.url.pathExtension.uppercased() + " 文件")
        previewIcon.isHidden = false
        previewIcon.image = NSWorkspace.shared.icon(forFile: item.url.path)

        if quickLookView == nil, let view = QLPreviewView(frame: previewContainer.bounds.insetBy(dx: 8, dy: 8), style: .normal) {
            view.autoresizingMask = [.width, .height]
            view.shouldCloseWithWindow = false
            previewContainer.addSubview(view, positioned: .below, relativeTo: previewIcon)
            quickLookView = view
        }
        if item.isDirectory {
            quickLookView?.isHidden = true
            quickLookView?.previewItem = nil
        } else {
            quickLookView?.previewItem = item.url as NSURL
            quickLookView?.isHidden = false
            previewIcon.isHidden = true
        }

        let values = fileInfo(for: item.url)
        for (index, value) in values.enumerated() where index < infoRows.count {
            infoRows[index].stringValue = value
        }
    }

    private func fileInfo(for url: URL) -> [String] {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let creation = attributes?[.creationDate] as? Date
        let modification = attributes?[.modificationDate] as? Date
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        let ext = url.pathExtension.uppercased()
        let kind = ext.isEmpty ? "文件夹" : "\(ext) 文件"
        let snippet = selected?.matchedSnippet ?? (currentQuery.isEmpty ? "—" : "Spotlight 索引命中")
        return [
            url.path,
            creation.map { formatter.string(from: $0) } ?? "—",
            modification.map { formatter.string(from: $0) } ?? "—",
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file),
            kind,
            snippet
        ]
    }

    // MARK: - Toolbar actions

    @objc func toolbarAction(_ sender: NSButton) {
        guard let item = selected else { return }
        switch sender.tag {
        case 0: openSelected()
        case 1:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([item.url as NSURL])
        case 2: NSWorkspace.shared.activateFileViewerSelecting([item.url])
        case 3:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.url.path, forType: .string)
        case 4, 5: chooseDestination(for: item, copy: sender.tag == 5)
        case 6:
            if let service = NSSharingService(named: .sendViaAirDrop) { service.perform(withItems: [item.url]) }
        case 7: showFinderInfo(item.url)
        default: break
        }
    }

    @objc private func openSelected() {
        guard let item = selected else { return }
        NSWorkspace.shared.open(item.url)
    }

    private func chooseDestination(for item: MSFileResult, copy: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = copy ? "复制到这里" : "移动到这里"
        panel.beginSheetModal(for: self.panel) { response in
            guard response == .OK, let destination = panel.url else { return }
            let target = destination.appendingPathComponent(item.name)
            do {
                if copy { try FileManager.default.copyItem(at: item.url, to: target) }
                else { try FileManager.default.moveItem(at: item.url, to: target) }
                MSLogger.log(copy ? "已复制:" : "已移动:", target.path)
            } catch {
                MSLogger.log("文件操作失败:", error.localizedDescription)
            }
        }
    }

    private func showFinderInfo(_ url: URL) {
        let path = url.path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Finder\" to open information window of (POSIX file \"\(path)\" as alias)"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error { MSLogger.log("显示简介失败:", error) }
    }
}
