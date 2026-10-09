import Foundation
import CoreAudio
import Foundation

struct CoreAudioError: Error, CustomStringConvertible {
    let what: String
    let status: OSStatus
    var description: String { "\(what) 失败（OSStatus \(status)）" }
}

func check(_ status: OSStatus, _ what: String) throws {
    guard status == noErr else { throw CoreAudioError(what: what, status: status) }
}

func propertyAddress(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

let systemObject = AudioObjectID(kAudioObjectSystemObject)

/// 读取定长属性。
func readProperty<T: BitwiseCopyable>(
    _ object: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    default value: T
) throws -> T {
    var address = propertyAddress(selector, scope: scope)
    var result = value
    var size = UInt32(MemoryLayout<T>.size)
    try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &result), "读取属性 \(selector)")
    return result
}

func writeProperty<T: BitwiseCopyable>(
    _ object: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    value: T
) throws {
    var address = propertyAddress(selector, scope: scope)
    var value = value
    try check(AudioObjectSetPropertyData(object, &address, 0, nil, UInt32(MemoryLayout<T>.size), &value), "写入属性 \(selector)")
}

/// 读取数组属性。
func readArrayProperty<T: BitwiseCopyable>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, element: T) throws -> [T] {
    var address = propertyAddress(selector)
    var size: UInt32 = 0
    try check(AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size), "读取属性大小 \(selector)")
    guard size > 0 else { return [] }
    var items = [T](repeating: element, count: Int(size) / MemoryLayout<T>.stride)
    try items.withUnsafeMutableBytes { bytes in
        try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, bytes.baseAddress!), "读取属性 \(selector)")
    }
    return items
}

func readStringProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String {
    var address = propertyAddress(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value), "读取字符串属性 \(selector)")
    return (value?.takeRetainedValue() as String?) ?? ""
}

/// 在主线程监听某个属性的变化，返回取消监听的闭包。
func addListener(
    _ object: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    _ handler: @escaping @MainActor () -> Void
) -> () -> Void {
    var address = propertyAddress(selector, scope: scope)
    let block: AudioObjectPropertyListenerBlock = { _, _ in
        MainActor.assumeIsolated { handler() }
    }
    AudioObjectAddPropertyListenerBlock(object, &address, .main, block)
    return {
        var address = address
        AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
    }
}

func defaultOutputDevice() throws -> AudioObjectID {
    try readProperty(systemObject, kAudioHardwarePropertyDefaultOutputDevice, default: AudioObjectID(0))
}
