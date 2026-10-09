import AppKit

/// 受控应用：用户主动添加、由本 App 管理音量的应用。见 CONTEXT.md。
struct ControlledApp: Codable, Identifiable, Equatable {
    let bundleID: String
    var name: String
    /// 应用音量：相对于系统音量的比例，0...1。
    var volume: Double = 1
    var isMuted = false

    var id: String { bundleID }
    var gain: Float { isMuted ? 0 : Float(volume) }

    var icon: NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// 受控应用列表的持久化，按添加顺序保存。
enum ControlledAppStore {
    private static let key = "controlledApps"

    static func load() -> [ControlledApp] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ControlledApp].self, from: data)) ?? []
    }

    static func save(_ apps: [ControlledApp]) {
        if let data = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
