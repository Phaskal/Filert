import SwiftUI

struct MenuBarMenuView: View {
    @ObservedObject private var manager = WatchlistManager.shared

    var body: some View {
        if manager.recentChanges.isEmpty {
            Text("변경 없음")
                .foregroundColor(.secondary)
        } else {
            Text("최근 변경")
                .foregroundColor(.secondary)
            Divider()
            ForEach(manager.recentChanges.prefix(10)) { record in
                Text("\(record.displayName)  \(record.formattedTime)")
                    .fontWeight(record.isRead ? .regular : .bold)
            }
            Divider()
            Button("모두 읽음 표시") { manager.markAllRead() }
        }

        Divider()

        if #available(macOS 14.0, *) {
            SettingsLink()
        } else {
            Button("설정...") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }

        Divider()
        Button("Filert 종료") { NSApplication.shared.terminate(nil) }
    }
}
