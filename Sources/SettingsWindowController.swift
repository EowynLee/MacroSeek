import AppKit
import Carbon.HIToolbox

final class MSSettingsWindowController: NSWindowController, NSTextFieldDelegate {

    static let shared = MSSettingsWindowController()

    private let loginButton = NSButton(checkboxWithTitle: "开机自启动", target: nil, action: #selector(toggleLogin(_:)))
    private let silentButton = NSButton(checkboxWithTitle: "开机静默启动（只驻留菜单栏，不弹搜索窗）", target: nil, action: #selector(toggleSilent(_:)))
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let recordButton = NSButton(title: "录制快捷键…", target: nil, action: #selector(recordHotkey(_:)))
    private let hintLabel = NSTextField(labelWithString: "")
    private var recording = false
    private var keyMonitor: Any?

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "MacroSeek 设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        loginButton.frame = NSRect(x: 28, y: 196, width: 380, height: 24)
        loginButton.target = self
        content.addSubview(loginButton)

        silentButton.frame = NSRect(x: 28, y: 162, width: 400, height: 24)
        silentButton.target = self
        content.addSubview(silentButton)

        let title = NSTextField(labelWithString: "唤出搜索快捷键")
        title.frame = NSRect(x: 28, y: 124, width: 120, height: 20)
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        content.addSubview(title)

        shortcutLabel.frame = NSRect(x: 150, y: 122, width: 120, height: 24)
        shortcutLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        shortcutLabel.textColor = .controlAccentColor
        content.addSubview(shortcutLabel)

        recordButton.frame = NSRect(x: 278, y: 118, width: 130, height: 30)
        recordButton.bezelStyle = .rounded
        recordButton.target = self
        content.addSubview(recordButton)

        hintLabel.frame = NSRect(x: 28, y: 72, width: 384, height: 40)
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.maximumNumberOfLines = 2
        hintLabel.stringValue = "快捷键需包含 ⌃ / ⌥ / ⇧ / ⌘ 中至少一个修饰键。\n登录项需将 App 放入“应用程序”文件夹后才能生效。"
        content.addSubview(hintLabel)

        let note = NSTextField(labelWithString: "版本 0.1 · 手写 AppKit 构建")
        note.frame = NSRect(x: 28, y: 20, width: 384, height: 18)
        note.font = NSFont.systemFont(ofSize: 10)
        note.textColor = .tertiaryLabelColor
        content.addSubview(note)
    }

    private func refresh() {
        loginButton.state = MSSettings.shared.loginItemEnabled ? .on : .off
        silentButton.state = MSSettings.shared.startSilently ? .on : .off
        shortcutLabel.stringValue = MSSettings.shared.hotkeyDisplayString()
    }

    func show() {
        // 搜索面板是 .floating；设置窗必须用更高层级，否则会被它挡在后面。
        window?.level = .modalPanel
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        MSLogger.log("设置窗口已置于最前, level:", window?.level.rawValue ?? -1)
    }

    func contains(_ point: NSPoint) -> Bool {
        window?.frame.contains(point) ?? false
    }

    @objc private func toggleLogin(_ sender: NSButton) {
        let desired = sender.state == .on
        let result = MSSettings.shared.setLoginItem(desired)
        if !result.0 {
            sender.state = desired ? .off : .on
            let alert = NSAlert()
            alert.messageText = "设置开机自启动失败"
            alert.informativeText = result.1
            alert.runModal()
        } else {
            MSLogger.log(result.1)
        }
    }

    @objc private func toggleSilent(_ sender: NSButton) {
        MSSettings.shared.startSilently = sender.state == .on
    }

    @objc private func recordHotkey(_ sender: NSButton) {
        if recording { stopRecording(); return }
        recording = true
        sender.title = "按下快捷键…"
        shortcutLabel.stringValue = "录制中…"
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording, event.window == self.window else { return event }
            if event.keyCode == 53 { self.stopRecording(); return nil }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !flags.isEmpty else { return nil }
            let code = UInt32(event.keyCode)
            MSSettings.shared.hotkeyKeyCode = code
            MSSettings.shared.hotkeyCarbonModifiers = MSHotkeyManager.carbonModifiers(from: flags)
            AppDelegate.shared?.reregisterHotkey()
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor); keyMonitor = nil }
        recordButton.title = "录制快捷键…"
        shortcutLabel.stringValue = MSSettings.shared.hotkeyDisplayString()
    }
}
