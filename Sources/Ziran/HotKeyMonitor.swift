import Carbon.HIToolbox

private let ziranHotKeySignature: OSType = 0x5A52414E

private func ziranHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return noErr }
    var hotKeyID = EventHotKeyID()
    guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                            MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID) == noErr,
          hotKeyID.signature == ziranHotKeySignature else { return noErr }
    let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { monitor.fire(id: hotKeyID.id) }
    return noErr
}

@MainActor
final class HotKeyMonitor {
    private var handlerRef: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef?] = []
    private var actions: [() -> Void] = []

    func register(keyCode: Int, modifiers: Int, action: @escaping () -> Void) -> Bool {
        if handlerRef == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            guard InstallEventHandler(GetApplicationEventTarget(), ziranHotKeyHandler, 1, &spec,
                                      Unmanaged.passUnretained(self).toOpaque(), &handlerRef) == noErr else { return false }
        }
        var hotKey: EventHotKeyRef?
        let id = EventHotKeyID(signature: ziranHotKeySignature, id: UInt32(actions.count))
        guard RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(),
                                  OptionBits(kEventHotKeyExclusive), &hotKey) == noErr else { return false }
        actions.append(action)
        hotKeys.append(hotKey)
        return true
    }

    fileprivate func fire(id: UInt32) {
        guard id < actions.count else { return }
        actions[Int(id)]()
    }
}
