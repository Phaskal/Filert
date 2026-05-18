import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var manager = WatchlistManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("감시 목록")
                .font(.headline)
                .padding([.top, .horizontal], 16)
                .padding(.bottom, 8)

            Divider()

            if manager.watchedPaths.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("감시 중인 항목이 없습니다")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("아래 + 버튼을 눌러 폴더 또는 파일을 추가하세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(manager.watchedPaths) { watched in
                        WatchedPathRow(watched: watched)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: addPath) {
                    Image(systemName: "plus")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .help("폴더 또는 파일 추가")

                Spacer()

                if !manager.recentChanges.isEmpty {
                    Button("기록 지우기") {
                        manager.recentChanges.removeAll()
                        manager.hasUnreadChanges = false
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Text("\(manager.watchedPaths.count)개 감시 중")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(width: 440, height: 340)
    }

    private func addPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "감시 추가"
        panel.message = "감시할 파일 또는 폴더를 선택하세요"

        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                WatchlistManager.shared.addPath(url.path)
            }
        }
    }
}

struct WatchedPathRow: View {
    let watched: WatchedPath

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: watched.isActive ? "eye.fill" : "eye.slash")
                .foregroundColor(watched.isActive ? .accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(watched.displayName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(watched.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { watched.isActive },
                set: { _ in WatchlistManager.shared.togglePath(id: watched.id) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            Button {
                WatchlistManager.shared.removePath(id: watched.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.borderless)
            .help("감시 목록에서 제거")
        }
        .padding(.vertical, 3)
    }
}
