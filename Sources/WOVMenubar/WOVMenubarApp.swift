import AppKit
import SwiftUI

@main
struct WOVMenubarApp: App {
    @NSApplicationDelegateAdaptor(WOVAppDelegate.self) private var appDelegate
    @StateObject private var context = WOVAppContext.shared

    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            Task { @MainActor in
                WOVQuickNotesWindowPresenter.shared.showQuickNotesWindow()
            }
        }
    }

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

@MainActor
private final class WOVAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        WOVQuickNotesWindowPresenter.shared.showQuickNotesWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WOVQuickNotesWindowPresenter.shared.showQuickNotesWindow()
        return true
    }
}

@MainActor
private final class WOVQuickNotesWindowPresenter {
    static let shared = WOVQuickNotesWindowPresenter()

    private var window: NSWindow?

    private init() {}

    func showQuickNotesWindow() {
        NSApplication.shared.setActivationPolicy(.regular)

        if window == nil {
            let content = QuickNoteWindowContent(
                model: WOVAppContext.shared.model,
                appUpdater: WOVAppContext.shared.appUpdater
            )
            let hostingView = NSHostingView(rootView: content)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 760),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "WOV Quick Notes"
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct QuickNoteWindowContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var appUpdater: AppUpdater

    var body: some View {
        QuickNoteMenuView()
            .environmentObject(model)
            .environmentObject(appUpdater)
            .frame(width: 480)
    }
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
