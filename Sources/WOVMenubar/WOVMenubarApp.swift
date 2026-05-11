import SwiftUI

@main
struct WOVMenubarApp: App {
    @StateObject private var context = WOVAppContext.shared

    var body: some Scene {
        MenuBarExtra {
            QuickNoteMenuBarContent(model: context.model, appUpdater: context.appUpdater)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "mic.fill")
                Text("WOV")
                    .font(.system(size: 12, weight: .semibold))
            }
            .accessibilityLabel("WOV Quick Notes")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
private final class WOVAppContext: ObservableObject {
    static let shared = WOVAppContext()

    let model = AppModel()
    let appUpdater = AppUpdater()

    private init() {}
}

private struct QuickNoteMenuBarContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var appUpdater: AppUpdater

    var body: some View {
        QuickNoteMenuView()
            .environmentObject(model)
            .environmentObject(appUpdater)
            .frame(width: 480)
    }
}
