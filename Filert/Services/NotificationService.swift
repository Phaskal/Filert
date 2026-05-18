import UserNotifications
import AppKit

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let categoryID   = "FILE_CHANGE"
    private let openActionID = "OPEN_FILE"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermissions() {
        let openAction = UNNotificationAction(
            identifier: openActionID,
            title: "파일 열기",
            options: []
        )
        let closeAction = UNNotificationAction(
            identifier: "CLOSE",
            title: "닫기",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [openAction, closeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func send(for record: ChangeRecord) {
        let content = UNMutableNotificationContent()
        content.title = record.displayName
        content.body = "변경됨: \(record.formattedTime)"
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = ["path": record.path]

        let request = UNNotificationRequest(
            identifier: record.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // Show banner even while app is running
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle action button taps
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard response.actionIdentifier == openActionID ||
              response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let path = response.notification.request.content.userInfo["path"] as? String
        else { return }

        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            NSWorkspace.shared.open(url)
        } else {
            // 파일이면 Finder에서 선택하여 위치를 표시
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
