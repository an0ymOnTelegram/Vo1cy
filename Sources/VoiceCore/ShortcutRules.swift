import Foundation

public struct ModifierKey: Equatable {
    public let code: UInt32
    public let label: String
    public let physicalMask: UInt64
    public let familyMask: UInt64
    public let aggregateMask: UInt64
    public let carbonMask: UInt32
}

public enum ShortcutKeys {
    // Virtual key codes and flag bits from macOS Events.h / IOLLEvent.h.
    public static let modifiers: [ModifierKey] = [
        .init(code: 55, label: "Left ⌘", physicalMask: 0x08, familyMask: 0x18, aggregateMask: 1 << 20, carbonMask: 256),
        .init(code: 54, label: "Right ⌘", physicalMask: 0x10, familyMask: 0x18, aggregateMask: 1 << 20, carbonMask: 256),
        .init(code: 56, label: "Left ⇧", physicalMask: 0x02, familyMask: 0x06, aggregateMask: 1 << 17, carbonMask: 512),
        .init(code: 60, label: "Right ⇧", physicalMask: 0x04, familyMask: 0x06, aggregateMask: 1 << 17, carbonMask: 512),
        .init(code: 58, label: "Left ⌥", physicalMask: 0x20, familyMask: 0x60, aggregateMask: 1 << 19, carbonMask: 2048),
        .init(code: 61, label: "Right ⌥", physicalMask: 0x40, familyMask: 0x60, aggregateMask: 1 << 19, carbonMask: 2048),
        .init(code: 59, label: "Left Ctrl", physicalMask: 0x01, familyMask: 0x2001, aggregateMask: 1 << 18, carbonMask: 4096),
        .init(code: 62, label: "Right Ctrl", physicalMask: 0x2000, familyMask: 0x2001, aggregateMask: 1 << 18, carbonMask: 4096),
        .init(code: 63, label: "Fn / Globe", physicalMask: 1 << 23, familyMask: 1 << 23, aggregateMask: 1 << 23, carbonMask: 0)
    ]
    public static func modifier(_ code: UInt32) -> ModifierKey? { modifiers.first { $0.code == code } }
    public static func isDown(_ code: UInt32, flags: UInt64) -> Bool {
        guard let key = modifier(code) else { return false }
        if flags & key.familyMask != 0 { return flags & key.physicalMask != 0 }
        return flags & key.aggregateMask != 0
    }
    public static func otherModifiersDown(_ code: UInt32, flags: UInt64) -> Bool {
        guard let key = modifier(code) else { return false }
        let all: UInt64 = (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20) | (1 << 23)
        return flags & (all & ~key.aggregateMask) != 0 || flags & (key.familyMask & ~key.physicalMask) != 0
    }
    public static func carbonModifiers(flags: UInt64) -> UInt32 {
        modifiers.reduce(UInt32(0)) { $0 | (flags & $1.aggregateMask == 0 ? 0 : $1.carbonMask) }
    }
    public static func label(code: UInt32, characters: String?) -> String {
        if let key = modifier(code) { return key.label }
        let names: [UInt32: String] = [49: "Space", 36: "Return", 48: "Tab", 51: "⌫", 117: "⌦", 76: "Enter", 123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page ↑", 121: "Page ↓",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"]
        return names[code] ?? (characters?.isEmpty == false ? characters!.uppercased() : "Key \(code)")
    }
}

/// One down/up pair per physical press, even when the system repeats hotkey events.
public struct ShortcutLatch {
    public private(set) var held = false
    public init() {}
    public mutating func update(down: Bool) -> Bool {
        guard down != held else { return false }; held = down; return true
    }
    public mutating func reset() { held = false }
}

/// A standalone modifier is recorded on release, never in the middle of a chord.
public struct ModifierCapture {
    private var candidate: UInt32?
    private var chord = false
    public init() {}
    public mutating func change(code: UInt32, down: Bool, othersDown: Bool) -> UInt32? {
        if down {
            if candidate == nil && !chord && !othersDown { candidate = code }
            else { candidate = nil; chord = true }
            return nil
        }
        let result = candidate == code && !chord && !othersDown ? code : nil
        candidate = nil
        if !othersDown { chord = false }
        return result
    }
}
