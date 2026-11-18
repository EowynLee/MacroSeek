import Foundation
import AppKit
import ServiceManagement
import Carbon.HIToolbox

final class MSSettings {
    static let shared = MSSettings()

    private let defaults = UserDefaults.standard
    private let keyHotkeyCode = "MacroSeek.hotkey.keyCode"
    private let keyHotkeyModifiers = "MacroSeek.hotkey.modifiers"
    private let keySilentStart = "MacroSeek.silentStart"

    var hotkeyKeyCode: UInt32 {
        get {
            let stored = defaults.object(forKey: keyHotkeyCode) as? Int
            return UInt32(stored ?? 49) // 49 = Space
        }
        set { defaults.set(Int(newValue), forKey: keyHotkeyCode) }
    }

    var hotkeyCarbonModifiers: UInt32 {
        get {
            let stored = defaults.object(forKey: keyHotkeyModifiers) as? Int
            let fallback = Int(UInt32(controlKey) | UInt32(optionKey))
            return UInt32(stored ?? fallback)
        }
        set { defaults.set(Int(newValue), forKey: keyHotkeyModifiers) }
    }

    var startSilently: Bool {
        get { defaults.object(forKey: keySilentStart) as? Bool ?? true }
        set { defaults.set(newValue, forKey: keySilentStart) }
    }

    var loginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 开机静默启动：登录项已启用，且本次进程启动发生在系统开机后的短时间内（近似判断登录阶段）。
    var launchedAtLogin: Bool {
        guard loginItemEnabled else { return false }
        return ProcessInfo.processInfo.systemUptime < 180
    }

    var shouldShowWindowOnLaunch: Bool {
        !(startSilently && launchedAtLogin)
    }

    func setLoginItem(_ enabled: Bool) -> (Bool, String) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                return (true, "已开启开机自启动")
            } else {
                try SMAppService.mainApp.unregister()
                return (true, "已关闭开机自启动")
            }
        } catch {
            MSLogger.log("登录项设置失败:", error.localizedDescription)
            return (false, error.localizedDescription)
        }
    }

    func hotkeyDisplayString() -> String {
        var parts: [String] = []
        let m = hotkeyCarbonModifiers
        if m & UInt32(controlKey) != 0 { parts.append("⌃") }
        if m & UInt32(optionKey) != 0 { parts.append("⌥") }
        if m & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if m & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: hotkeyKeyCode))
        return parts.joined()
    }

    static func keyName(for code: UInt32) -> String {
        switch code {
        case 49: return "空格"
        case 36: return "Return"
        case 48: return "Tab"
        case 53: return "Esc"
        case 51: return "Delete"
        default:
            if let ch = UCKeyTranslateCharacter(code) { return ch }
            return "键码\(code)"
        }
    }

    private static func UCKeyTranslateCharacter(_ code: UInt32) -> String? {
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let layout = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let data = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = unsafeBitCast(data, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
        let status = UCKeyTranslate(keyboardLayout, UInt16(code), UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, 4, &length, &chars)
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
