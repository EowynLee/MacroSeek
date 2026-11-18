import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var panelController = MSPanelController()
    private var statusMenu: NSMenu!
    private var globalMouseMonitor: Any?
    private var searchMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
        buildStatusItem()
        reregisterHotkey()
        observeVolumes()
        installOutsideClickMonitor()

        if MSSettings.shared.shouldShowWindowOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.panelController.show()
            }
        }
        MSLogger.log("MacroSeek 启动，静默:", MSSettings.shared.startSilently, "登录启动:", MSSettings.shared.launchedAtLogin)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Status item

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            // 用 NSImage(named:) 让 AppKit 按屏幕 scale 自动选取 22px / 44px(@2x) 表示，Retina 下不再被拉伸发糊
            let image = NSImage(named: "MenuIcon") ?? Bundle.main.image(forResource: "MenuIcon")
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "左键唤出搜索 · 右键打开菜单"
        }

        statusMenu = NSMenu()
        searchMenuItem = NSMenuItem(title: "打开搜索窗口", action: #selector(showPanel), keyEquivalent: "")
        searchMenuItem.target = self
        statusMenu.addItem(searchMenuItem)

        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        statusMenu.addItem(settings)

        let refresh = NSMenuItem(title: "重新扫描网络硬盘", action: #selector(refreshVolumes), keyEquivalent: "r")
        refresh.target = self
        statusMenu.addItem(refresh)

        statusMenu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "退出 MacroSeek", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        statusMenu.addItem(quit)
        statusMenu.delegate = self
    }

    func menuWillOpen(_ menu: NSMenu) {
        searchMenuItem.title = "打开搜索窗口  \(MSSettings.shared.hotkeyDisplayString())"
    }

    @objc private func togglePanel() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp,
           let button = statusItem?.button {
            statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 4), in: button)
            return
        }
        panelController.toggle()
    }
    @objc private func showPanel() { panelController.show() }
    @objc private func openSettings() { MSSettingsWindowController.shared.show() }
    @objc private func quitApp() { NSApp.terminate(nil) }
    @objc private func refreshVolumes() {
        MSSearchEngine.shared.refreshVolumes()
        panelController.refreshSearch()
    }

    // MARK: - Hotkey

    func reregisterHotkey() {
        MSHotkeyManager.shared.register(keyCode: MSSettings.shared.hotkeyKeyCode,
                                        carbonModifiers: MSSettings.shared.hotkeyCarbonModifiers) { [weak self] in
            self?.panelController.toggle()
        }
    }

    // MARK: - Volume reconnect

    private func observeVolumes() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification,
                     NSWorkspace.didUnmountNotification,
                     NSWorkspace.didRenameVolumeNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MSLogger.log("卷发生变化:", name.rawValue)
                MSSearchEngine.shared.refreshVolumes()
                self?.panelController.refreshSearch()
            }
        }
    }

    // MARK: - Click outside to hide

    private func installOutsideClickMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panelController.panel.isVisible else { return }
            let point = NSEvent.mouseLocation
            if self.panelController.contains(point) { return }
            if MSSettingsWindowController.shared.contains(point) { return }
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }),
               point.y > screen.frame.maxY - 24 { return } // 菜单栏点击交给状态栏处理
            self.panelController.hide()
        }
    }

    deinit {
        if let monitor = globalMouseMonitor { NSEvent.removeMonitor(monitor) }
    }
}

// 手写入口：不依赖 Xcode 工程或 Storyboard。
let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.run()
