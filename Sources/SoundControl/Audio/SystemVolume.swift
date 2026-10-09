import AudioToolbox
import CoreAudio

/// 默认输出设备的系统音量。设备不支持调节时 isAdjustable 为 false。
@MainActor
final class SystemVolume: ObservableObject {
    @Published private(set) var volume: Float = 0
    @Published private(set) var isAdjustable = false

    private var device = AudioObjectID(kAudioObjectUnknown)
    private var removeListener: (() -> Void)?
    private let selector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
    private let scope = kAudioDevicePropertyScopeOutput

    /// 绑定到当前默认输出设备。
    func rebind() {
        removeListener?()
        removeListener = nil
        device = (try? defaultOutputDevice()) ?? AudioObjectID(kAudioObjectUnknown)

        var address = propertyAddress(selector, scope: scope)
        var settable: DarwinBoolean = false
        isAdjustable = AudioObjectHasProperty(device, &address)
            && AudioObjectIsPropertySettable(device, &address, &settable) == noErr
            && settable.boolValue
        if isAdjustable {
            removeListener = addListener(device, selector, scope: scope) { [weak self] in self?.refresh() }
        }
        refresh()
    }

    func set(_ value: Float) {
        guard isAdjustable else { return }
        volume = value
        try? writeProperty(device, selector, scope: scope, value: Float32(value))
    }

    private func refresh() {
        volume = isAdjustable ? ((try? readProperty(device, selector, scope: scope, default: Float32(0))) ?? 0) : 1
    }
}
