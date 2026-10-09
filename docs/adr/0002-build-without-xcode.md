# 不使用 Xcode，用 Swift Package Manager + 脚本打包 .app

开发机磁盘空间有限，而 Command Line Tools 已包含所需的 Swift 工具链、macOS SDK（含 Process Tap、SwiftUI、ServiceManagement），所以项目不建 .xcodeproj：用 SwiftPM 编译，由脚本组装 .app（Info.plist 中声明音频录制用途、LSUIElement 隐藏 Dock 图标）并签名。

## Consequences

- 没有 Xcode 的界面设计器和调试器，靠日志排查。
- 必须用钥匙串中的固定自签名代码签名证书签名，否则每次重新编译后 macOS 都会重新索要"系统音频录制"权限。
