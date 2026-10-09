import AppKit
import CoreAudio

private typealias ResponsiblePIDFunction = @convention(c) (pid_t) -> pid_t

/// 私有但稳定的系统函数：找出负责某个进程的"主进程"，
/// 例如 Safari 的声音来自 com.apple.WebKit.GPU 进程，它的负责进程是 Safari。
private let responsiblePID: ResponsiblePIDFunction? = {
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else { return nil }
    return unsafeBitCast(symbol, to: ResponsiblePIDFunction.self)
}()

/// Core Audio 中的一个音频进程对象。
struct AudioProcess {
    let objectID: AudioObjectID
    /// 进程自身的 Bundle ID，如 com.google.Chrome.helper。
    let bundleID: String
    /// 负责该进程的应用的 Bundle ID，如 com.google.Chrome。
    let owningBundleID: String?
    let isRunningOutput: Bool

    /// 该进程是否属于某个应用（含其辅助进程）。
    func belongs(to appBundleID: String) -> Bool {
        owningBundleID == appBundleID || bundleID == appBundleID || bundleID.hasPrefix(appBundleID + ".")
    }

    static func all() -> [AudioProcess] {
        let ids = (try? readArrayProperty(systemObject, kAudioHardwarePropertyProcessObjectList, element: AudioObjectID(0))) ?? []
        return ids.map { id in
            let pid = (try? readProperty(id, kAudioProcessPropertyPID, default: pid_t(0))) ?? 0
            var owner = pid
            if let responsiblePID, case let responsible = responsiblePID(pid), responsible > 0 { owner = responsible }
            return AudioProcess(
                objectID: id,
                bundleID: (try? readStringProperty(id, kAudioProcessPropertyBundleID)) ?? "",
                owningBundleID: NSRunningApplication(processIdentifier: owner)?.bundleIdentifier,
                isRunningOutput: ((try? readProperty(id, kAudioProcessPropertyIsRunningOutput, default: UInt32(0))) ?? 0) != 0
            )
        }
    }
}
