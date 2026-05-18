import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var sleepWakeMonitor: SleepWakeMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationService.shared.requestPermissions()
        sleepWakeMonitor = SleepWakeMonitor()
        WatchlistManager.shared.startWatching()
    }

    func applicationWillTerminate(_ notification: Notification) {
        WatchlistManager.shared.stopWatching()
    }
}
