import Foundation

class ICloudMonitor {
    private var metadataQuery: NSMetadataQuery?
    private var watchedPaths: [String] = []
    var onChange: ((String, Date) -> Void)?

    func start(paths: [String]) {
        stop()
        watchedPaths = paths
        guard !paths.isEmpty else { return }

        let query = NSMetadataQuery()
        query.searchScopes = [
            NSMetadataQueryUbiquitousDocumentsScope,
            NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope
        ]
        query.predicate = NSPredicate(value: true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        query.start()
        metadataQuery = query
    }

    func stop() {
        guard let query = metadataQuery else { return }
        query.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: query)
        metadataQuery = nil
    }

    // Called by WatchlistManager.performWakeScan() to find iCloud files changed while asleep
    func changedItemsSince(lastSeenDates: [String: Date]) -> [(path: String, date: Date)] {
        guard let query = metadataQuery else { return [] }
        var results: [(String, Date)] = []

        query.disableUpdates()
        defer { query.enableUpdates() }

        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  isWatched(path: path),
                  let changeDate = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
            else { continue }

            if let lastSeen = lastSeenDates[path], changeDate > lastSeen {
                results.append((path, changeDate))
            }
        }
        return results
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        guard let query = metadataQuery else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }

        let changed = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]) ?? []
        let added   = (notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey]   as? [NSMetadataItem]) ?? []

        for item in changed + added {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  isWatched(path: path)
            else { continue }

            let date = (item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date) ?? Date()
            DispatchQueue.main.async { self.onChange?(path, date) }
        }
    }

    private func isWatched(path: String) -> Bool {
        watchedPaths.contains { path.hasPrefix($0) || path == $0 }
    }

    deinit { stop() }
}
