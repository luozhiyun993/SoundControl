import Foundation

/// "系统音频录制"权限。系统没有公开的查询接口，这里通过 TCC 私有框架查询和请求，
/// 与开源项目 AudioCap 的做法一致；仅自用，可接受。
enum AudioCapturePermission {
    enum Status { case unknown, authorized, denied }

    nonisolated(unsafe) private static let service = "kTCCServiceAudioCapture" as CFString
    nonisolated(unsafe) private static let tcc = dlopen("/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC", RTLD_NOW)

    static func status() -> Status {
        typealias Preflight = @convention(c) (CFString, CFDictionary?) -> Int
        guard let symbol = dlsym(tcc, "TCCAccessPreflight") else { return .unknown }
        switch unsafeBitCast(symbol, to: Preflight.self)(service, nil) {
        case 0: return .authorized
        case 1: return .denied
        default: return .unknown
        }
    }

    /// 弹出系统授权窗口；completion 在主线程回调。
    static func request(_ completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        typealias Request = @convention(c) (CFString, CFDictionary?, @convention(block) (Bool) -> Void) -> Void
        guard let symbol = dlsym(tcc, "TCCAccessRequest") else {
            Task { @MainActor in completion(false) }
            return
        }
        unsafeBitCast(symbol, to: Request.self)(service, nil) { granted in
            Task { @MainActor in completion(granted) }
        }
    }

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!
}
