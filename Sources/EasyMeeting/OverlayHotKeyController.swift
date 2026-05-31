import Carbon.HIToolbox
import Foundation

final class OverlayHotKeyController {
    private enum HotKey: UInt32 {
        case moveLeft = 1
        case moveRight
        case moveDown
        case moveUp
        case enlarge
        case enlargeWithPlus
        case shrink
        case reset
    }

    @MainActor private static weak var activeController: OverlayHotKeyController?

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private let actions: [HotKey: @MainActor () -> Void]

    @MainActor
    init(
        moveUp: @escaping @MainActor () -> Void,
        moveDown: @escaping @MainActor () -> Void,
        moveLeft: @escaping @MainActor () -> Void,
        moveRight: @escaping @MainActor () -> Void,
        enlarge: @escaping @MainActor () -> Void,
        shrink: @escaping @MainActor () -> Void,
        reset: @escaping @MainActor () -> Void
    ) {
        actions = [
            .moveUp: moveUp,
            .moveDown: moveDown,
            .moveLeft: moveLeft,
            .moveRight: moveRight,
            .enlarge: enlarge,
            .enlargeWithPlus: enlarge,
            .shrink: shrink,
            .reset: reset
        ]
        Self.activeController = self
        installHandler()
        registerHotKeys()
    }

    deinit {
        hotKeyRefs.forEach { ref in
            if let ref {
                UnregisterEventHotKey(ref)
            }
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                Task { @MainActor in
                    OverlayHotKeyController.activeController?.handle(hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        if status != noErr {
            NSLog("Easy Meeting 全局快捷键监听安装失败：\(status)")
        }
    }

    private func registerHotKeys() {
        register(.moveLeft, keyCode: 123, modifiers: cmdKey)
        register(.moveRight, keyCode: 124, modifiers: cmdKey)
        register(.moveDown, keyCode: 125, modifiers: cmdKey)
        register(.moveUp, keyCode: 126, modifiers: cmdKey)
        register(.enlarge, keyCode: 24, modifiers: cmdKey)
        register(.enlargeWithPlus, keyCode: 24, modifiers: cmdKey | shiftKey)
        register(.shrink, keyCode: 27, modifiers: cmdKey)
        register(.reset, keyCode: 29, modifiers: cmdKey)
    }

    private func register(_ hotKey: HotKey, keyCode: UInt32, modifiers: Int) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: hotKey.rawValue)
        let status = RegisterEventHotKey(
            keyCode,
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            hotKeyRefs.append(hotKeyRef)
        } else {
            NSLog("Easy Meeting 全局快捷键注册失败：\(hotKey.rawValue)，状态：\(status)")
        }
    }

    @MainActor
    private func handle(_ id: UInt32) {
        guard let hotKey = HotKey(rawValue: id) else { return }
        actions[hotKey]?()
    }

    private static let signature: OSType = {
        let scalars = Array("EMHK".unicodeScalars)
        return scalars.reduce(UInt32(0)) { value, scalar in
            (value << 8) + scalar.value
        }
    }()
}
