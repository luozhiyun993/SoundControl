import AppKit
import UniformTypeIdentifiers

/// 点击"＋"弹出的菜单：上半部分是当前的发声应用，下面是"从应用程序文件夹选择…"。
@MainActor
final class AddAppMenu: NSObject {
    private let controller: SoundController

    private init(controller: SoundController) {
        self.controller = controller
    }

    static func show(controller: SoundController) {
        let handler = AddAppMenu(controller: controller)
        let menu = NSMenu()

        let sounding = controller.soundingApps()
        let header = NSMenuItem(title: sounding.isEmpty ? "没有正在发声的应用" : "正在发声", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for app in sounding {
            let item = NSMenuItem(title: app.localizedName ?? app.bundleIdentifier ?? "", action: #selector(addRunning(_:)), keyEquivalent: "")
            item.target = handler
            item.representedObject = app
            if let icon = app.icon {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let browse = NSMenuItem(title: "从应用程序文件夹选择…", action: #selector(browse), keyEquivalent: "")
        browse.target = handler
        menu.addItem(browse)

        // popUp 会一直阻塞到菜单关闭，handler 在此期间保持存活。
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        withExtendedLifetime(handler) {}
    }

    @objc private func addRunning(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? NSRunningApplication, let id = app.bundleIdentifier else { return }
        controller.add(bundleID: id, name: app.localizedName ?? id)
    }

    @objc private func browse() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.prompt = "添加"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let id = Bundle(url: url)?.bundleIdentifier else { continue }
            controller.add(bundleID: id, name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
        }
    }
}
