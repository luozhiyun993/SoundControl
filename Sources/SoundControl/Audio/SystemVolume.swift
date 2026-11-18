import AudioToolbox
import CoreAudio

/// 默认输出设备的系统音量和静音。设备不支持调节时 isAdjustable / isMutable 为 false。
@MainActor
final class SystemVolume: ObservableObject {
    @Published private(set) var volume: Float = 0
    @Published private(set) var isAdjustable = false
    @Published private(set) var isMuted = false
    @Published private(set) var isMutable = false

    private var device = AudioObjectID(kAudioObjectUnknown)
    private var removeListeners: [() -> Void] = []
    private let volumeSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
    private let muteSelector = kAudioDevicePropertyMute
    private let scope = kAudioDevicePropertyScopeOutput

    /// 绑定到当前默认输出设备。
    func rebind() {
        removeListeners.forEach { $0() }
        removeListeners.removeAll()
        device = (try? defaultOutputDevice()) ?? AudioObjectID(kAudioObjectUnknown)

        isAdjustable = isSettable(volumeSelector)
        isMutable = isSettable(muteSelector)
        if isAdjustable {
            removeListeners.append(addListener(device, volumeSelector, scope: scope) { [weak self] in self?.refresh() })
        }
        if isMutable {
            removeListeners.append(addListener(device, muteSelector, scope: scope) { [weak self] in self?.refresh() })
        }
        refresh()
    }

    /// 与系统行为一致：调节音量时取消静音。
    func set(_ value: Float) {
        guard isAdjustable else { return }
        volume = value
        try? writeProperty(device, volumeSelector, scope: scope, value: Float32(value))
        if isMuted { setMuted(false) }
    }

    func toggleMute() {
        setMuted(!isMuted)
    }

    private func setMuted(_ muted: Bool) {
        guard isMutable else { return }
        isMuted = muted
        try? writeProperty(device, muteSelector, scope: scope, value: UInt32(muted ? 1 : 0))
    }

    private func isSettable(_ selector: AudioObjectPropertySelector) -> Bool {
        var address = propertyAddress(selector, scope: scope)
        var settable: DarwinBoolean = false
        return AudioObjectHasProperty(device, &address)
            && AudioObjectIsPropertySettable(device, &address, &settable) == noErr
            && settable.boolValue
    }

    private func refresh() {
        volume = isAdjustable ? ((try? readProperty(device, volumeSelector, scope: scope, default: Float32(0))) ?? 0) : 1
        isMuted = isMutable && ((try? readProperty(device, muteSelector, scope: scope, default: UInt32(0))) ?? 0) != 0
    }
}
