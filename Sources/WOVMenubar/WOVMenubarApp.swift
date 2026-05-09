import AppKit
import SwiftUI

@main
struct WOVMenubarApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var appUpdater = AppUpdater()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("WOV Quick Notes", systemImage: "waveform.circle") {
            QuickNoteMenuView()
                .environmentObject(model)
                .environmentObject(appUpdater)
                .frame(width: 480)
        }
        .menuBarExtraStyle(.window)
    }
}
