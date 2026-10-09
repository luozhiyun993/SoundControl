import SwiftUI

/// 菜单栏弹出面板。
struct MenuPanel: View {
    @ObservedObject var controller: SoundController
    @ObservedObject var systemVolume: SystemVolume

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SoundControl").font(.headline)
                Spacer()
                Button { AddAppMenu.show(controller: controller) } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("添加受控应用")
            }

            if controller.permission == .denied {
                PermissionBanner()
            }

            systemVolumeRow

            Divider()

            if controller.apps.isEmpty {
                Text("暂无受控应用，点右上角 ＋ 添加")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(controller.apps) { app in
                    AppRow(app: app, controller: controller)
                }
            }

            if let error = controller.lastError {
                HStack(alignment: .top) {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Spacer()
                    Button { controller.lastError = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            Divider()

            HStack {
                Toggle("开机自启动", isOn: Binding(
                    get: { controller.launchAtLogin },
                    set: { controller.setLaunchAtLogin($0) }
                ))
                .toggleStyle(.checkbox)
                Spacer()
                Button("退出") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 340)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            controller.refreshPermission()
        }
    }

    private var systemVolumeRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "speaker.wave.3.fill").frame(width: 20)
                Text("系统音量").frame(width: 70, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(systemVolume.volume) },
                    set: { systemVolume.set(Float($0)) }
                ), in: 0...1)
                .disabled(!systemVolume.isAdjustable)
                Text(systemVolume.isAdjustable ? "\(Int((systemVolume.volume * 100).rounded()))%" : "—")
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }
            if !systemVolume.isAdjustable {
                Text("此设备不支持调节系统音量").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PermissionBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("未授权\"系统音频录制\"，应用音量不生效", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
            Button("打开系统设置") { NSWorkspace.shared.open(AudioCapturePermission.settingsURL) }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct AppRow: View {
    let app: ControlledApp
    let controller: SoundController

    var body: some View {
        HStack {
            Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
            Text(app.name).lineLimit(1).frame(width: 70, alignment: .leading)
            Button { controller.toggleMute(app) } label: {
                Image(systemName: app.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 18)
            }
            .buttonStyle(.borderless)
            .help(app.isMuted ? "取消静音" : "静音")
            Slider(value: Binding(
                get: { app.volume },
                set: { controller.setVolume($0, for: app) }
            ), in: 0...1)
            Text("\(Int((app.volume * 100).rounded()))%")
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
            Button { controller.remove(app) } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("移除")
        }
        .opacity(controller.isRunning(app) ? 1 : 0.45)
        .help(controller.isRunning(app) ? "" : "\(app.name) 未在运行，设置会在它启动后生效")
    }
}
