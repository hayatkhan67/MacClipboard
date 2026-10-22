import Foundation
import Carbon
import Cocoa

@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()
    
    public var onHotKeyTriggered: (() -> Void)?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    
    private init() {}
    
    public func setup() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let callback: EventHandlerUPP = { _, _, _ -> OSStatus in
            Task { @MainActor in
                HotKeyManager.shared.onHotKeyTriggered?()
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &eventHandlerRef)
        
        // 1. Primary shortcut: Command + Shift + V (Key code 9 = 'V')
        registerKey(id: 1, keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        
        // 2. Secondary shortcut: Option + V
        registerKey(id: 2, keyCode: 9, modifiers: UInt32(optionKey))
    }
    
    private func registerKey(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D434C50), id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let r = ref {
            hotKeyRefs.append(r)
        }
    }
    
    public func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let h = eventHandlerRef {
            RemoveEventHandler(h)
            eventHandlerRef = nil
        }
    }
}
