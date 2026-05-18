import AppKit

class SleepWakeMonitor {
    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func systemDidWake() {
        // Delay 3s to allow iCloud to sync metadata after wake
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            WatchlistManager.shared.performWakeScan()
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
