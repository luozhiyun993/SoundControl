import SwiftUI

@main
struct SoundControlApp: App {
    @StateObject private var controller = SoundController()

    var body: some Scene {
        MenuBarExtra("SoundControl", systemImage: "speaker.wave.2.fill") {
            MenuPanel(controller: controller, systemVolume: controller.systemVolume)
        }
        .menuBarExtraStyle(.window)
    }
}
