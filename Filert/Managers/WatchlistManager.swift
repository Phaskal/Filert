import Foundation
import Combine

class WatchlistManager: ObservableObject {
    static let shared = WatchlistManager()

    @Published var watchedPaths: [WatchedPath] = []
    @Published var recentChanges: [ChangeRecord] = []
    @Published var hasUnreadChanges = false

    private let fileWatcher = FileWatcherService()
    private let iCloudMonitor = ICloudMonitor()

    private var lastSeenDates: [String: Date] = [:]
    // Tracks recently notified paths to suppress duplicate events within a short window
    private var recentlyNotified: [String: Date] = [:]
    private let debounceInterval: TimeInterval = 4.0

    private let defaults = UserDefaults.standard
    private let pathsKey = "watchedPaths_v1"
    private let lastSeenKey = "lastSeenDates_v1"

    private init() {
        loadPaths()
        loadLastSeenDates()
    }

    // MARK: - Watching lifecycle

    func startWatching() {
        let active = watchedPaths.filter(\.isActive).map(\.path)

        fileWatcher.onChange = { [weak self] path, date in
            self?.handleChange(path: path, date: date)
        }
        iCloudMonitor.onChange = { [weak self] path, date in
            self?.handleChange(path: path, date: date)
        }

        fileWatcher.start(paths: active)
        iCloudMonitor.start(paths: active)
    }

    func stopWatching() {
        fileWatcher.stop()
        iCloudMonitor.stop()
    }

    private func restartWatching() {
        stopWatching()
        startWatching()
    }

    // MARK: - Change handling

    func handleChange(path: String, date: Date) {
        guard isActivelyWatched(path: path) else { return }

        // Debounce: skip if we already notified about this path very recently
        if let last = recentlyNotified[path], date.timeIntervalSince(last) < debounceInterval { return }
        recentlyNotified[path] = date
        lastSeenDates[path] = date
        saveLastSeenDates()

        let record = ChangeRecord(id: UUID(), path: path, changedAt: date, isRead: false)

        recentChanges.insert(record, at: 0)
        if recentChanges.count > 20 {
            recentChanges = Array(recentChanges.prefix(20))
        }
        hasUnreadChanges = true
        NotificationService.shared.send(for: record)
    }

    // MARK: - Wake scan (called by SleepWakeMonitor after system wake)

    func performWakeScan() {
        let active = watchedPaths.filter(\.isActive)
        for watched in active {
            scanLocalPath(watched.path)
        }
        // Also check iCloud items tracked by NSMetadataQuery
        for (path, date) in iCloudMonitor.changedItemsSince(lastSeenDates: lastSeenDates) {
            handleChange(path: path, date: date)
        }
    }

    private func scanLocalPath(_ path: String) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return }

        if isDir.boolValue {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else { return }
            for item in contents {
                let child = (path as NSString).appendingPathComponent(item)
                scanLocalPath(child)
            }
        } else {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let modDate = attrs[.modificationDate] as? Date else { return }

            if let lastSeen = lastSeenDates[path] {
                if modDate > lastSeen { handleChange(path: path, date: modDate) }
            } else {
                lastSeenDates[path] = modDate
            }
        }
    }

    // MARK: - Path management

    func addPath(_ path: String) {
        guard !watchedPaths.contains(where: { $0.path == path }) else { return }
        watchedPaths.append(WatchedPath(path: path))
        savePaths()
        restartWatching()
    }

    func removePath(id: UUID) {
        watchedPaths.removeAll { $0.id == id }
        savePaths()
        restartWatching()
    }

    func togglePath(id: UUID) {
        guard let idx = watchedPaths.firstIndex(where: { $0.id == id }) else { return }
        watchedPaths[idx].isActive.toggle()
        savePaths()
        restartWatching()
    }

    func markAllRead() {
        recentChanges = recentChanges.map { var r = $0; r.isRead = true; return r }
        hasUnreadChanges = false
    }

    // MARK: - Persistence

    private func savePaths() {
        if let data = try? JSONEncoder().encode(watchedPaths) {
            defaults.set(data, forKey: pathsKey)
        }
    }

    private func loadPaths() {
        guard let data = defaults.data(forKey: pathsKey),
              let paths = try? JSONDecoder().decode([WatchedPath].self, from: data) else { return }
        watchedPaths = paths
    }

    private func saveLastSeenDates() {
        if let data = try? JSONEncoder().encode(lastSeenDates) {
            defaults.set(data, forKey: lastSeenKey)
        }
    }

    private func loadLastSeenDates() {
        guard let data = defaults.data(forKey: lastSeenKey),
              let dates = try? JSONDecoder().decode([String: Date].self, from: data) else { return }
        lastSeenDates = dates
    }

    // MARK: - Helpers

    private func isActivelyWatched(path: String) -> Bool {
        watchedPaths.filter(\.isActive).contains {
            path.hasPrefix($0.path) || path == $0.path
        }
    }
}
