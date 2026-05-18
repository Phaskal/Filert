import SwiftUI

@main
struct FilertApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var manager = WatchlistManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView()
        } label: {
            Image(systemName: manager.hasUnreadChanges ? "doc.badge.clock.fill" : "doc.badge.clock")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}
