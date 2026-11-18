import AppKit
import Carbon.HIToolbox

final class MSHotkeyManager {
    static let shared = MSHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?
    private var installedHandler = false

    func register(keyCode: UInt32, carbonModifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        unregister(clearAction: false)

        if !installedHandler {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
                MSHotkeyManager.shared.action?()
                return noErr
            }, 1, &spec, nil, &eventHandler)
            if status == noErr { installedHandler = true }
            else { MSLogger.log("InstallEventHandler 失败:", status) }
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D534B31), id: 1) // MSK1
        let result = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if result != noErr {
            MSLogger.log("RegisterEventHotKey 失败:", result)
        } else {
            MSLogger.log("全局快捷键已注册 keyCode:", keyCode, "modifiers:", carbonModifiers)
        }
    }

    func unregister(clearAction: Bool = true) {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if clearAction { action = nil }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }
}
