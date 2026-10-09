import AppKit
import CoreAudio
import ServiceManagement

/// 管理受控应用列表，并让每个正在运行的受控应用都有一个对应的 AppVolumeTap。
@MainActor
final class SoundController: ObservableObject {
    @Published private(set) var apps: [ControlledApp] = ControlledAppStore.load()
    @Published private(set) var runningBundleIDs: Set<String> = []
    @Published private(set) var permission = AudioCapturePermission.status()
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var lastError: String?

    let systemVolume = SystemVolume()

    private var taps: [String: AppVolumeTap] = [:]
    private var isRequestingPermission = false
    private var removeListeners: [() -> Void] = []

    init() {
        systemVolume.rebind()
        refreshRunningApps()

        removeListeners.append(addListener(systemObject, kAudioHardwarePropertyProcessObjectList) { [weak self] in
            self?.syncTaps()
        })
        removeListeners.append(addListener(systemObject, kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in
            self?.systemVolume.rebind()
            self?.syncTaps(restartAll: true)
        })

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshRunningApps() }
            }
        }

        syncTaps()
    }

    // MARK: - 受控应用

    func add(bundleID: String, name: String) {
        guard !apps.contains(where: { $0.bundleID == bundleID }) else { return }
        apps.append(ControlledApp(bundleID: bundleID, name: name))
        ControlledAppStore.save(apps)
        syncTaps()
    }

    /// 移除后立即恢复原样，并清除设置。
    func remove(_ app: ControlledApp) {
        apps.removeAll { $0.bundleID == app.bundleID }
        ControlledAppStore.save(apps)
        syncTaps()
    }

    func setVolume(_ volume: Double, for app: ControlledApp) {
        update(app) { $0.volume = volume }
    }

    func toggleMute(_ app: ControlledApp) {
        update(app) { $0.isMuted.toggle() }
    }

    private func update(_ app: ControlledApp, _ change: (inout ControlledApp) -> Void) {
        guard let index = apps.firstIndex(where: { $0.bundleID == app.bundleID }) else { return }
        change(&apps[index])
        taps[app.bundleID]?.gain.value = apps[index].gain
        ControlledAppStore.save(apps)
    }

    func isRunning(_ app: ControlledApp) -> Bool {
        runningBundleIDs.contains(app.bundleID)
    }

    /// 发声应用：正在输出音频、但尚未受控的运行中应用。
    func soundingApps() -> [NSRunningApplication] {
        let outputting = AudioProcess.all().filter(\.isRunningOutput)
        let controlled = Set(apps.map(\.bundleID))
        return NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular,
                  let id = app.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier,
                  !controlled.contains(id) else { return false }
            return outputting.contains { $0.belongs(to: id) }
        }
    }

    private func refreshRunningApps() {
        runningBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    // MARK: - 权限

    /// 面板打开时调用，用户可能刚在系统设置里改了授权。
    func refreshPermission() {
        let newValue = AudioCapturePermission.status()
        guard newValue != permission else { return }
        permission = newValue
        syncTaps(restartAll: true)
    }

    // MARK: - 开机自启动

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = "设置开机自启动失败：\(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - 截获

    /// 让 taps 与"受控且正在发声的应用"保持一致。进程集合没变的 tap 保持不动，避免声音中断。
    private func syncTaps(restartAll: Bool = false) {
        if restartAll { stopAllTaps() }

        let processes = AudioProcess.all()
        var wanted: [String: [AudioObjectID]] = [:]
        for app in apps {
            let ids = processes.filter { $0.belongs(to: app.bundleID) }.map(\.objectID).sorted()
            if !ids.isEmpty { wanted[app.bundleID] = ids }
        }

        for (bundleID, tap) in taps where wanted[bundleID] != tap.processes {
            tap.stop()
            taps[bundleID] = nil
        }
        guard !wanted.isEmpty, wanted.keys.contains(where: { taps[$0] == nil }) else { return }

        // 未授权时截获只会得到静音，原声又被静音，所以宁可不截获。
        switch permission {
        case .denied:
            return
        case .unknown:
            requestPermission()
            return
        case .authorized:
            break
        }

        guard let outputUID = try? readStringProperty(try defaultOutputDevice(), kAudioDevicePropertyDeviceUID) else {
            lastError = "找不到默认输出设备"
            return
        }
        for app in apps {
            guard taps[app.bundleID] == nil, let ids = wanted[app.bundleID] else { continue }
            let tap = AppVolumeTap(processes: ids)
            tap.gain.value = app.gain
            do {
                try tap.start(outputUID: outputUID)
                taps[app.bundleID] = tap
            } catch {
                lastError = "接管 \(app.name) 失败：\(error)"
            }
        }
    }

    private func stopAllTaps() {
        taps.values.forEach { $0.stop() }
        taps.removeAll()
    }

    private func requestPermission() {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        AudioCapturePermission.request { [weak self] granted in
            guard let self else { return }
            isRequestingPermission = false
            permission = granted ? .authorized : .denied
            syncTaps()
        }
    }
}
