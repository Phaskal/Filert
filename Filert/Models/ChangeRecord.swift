import Foundation

struct ChangeRecord: Identifiable {
    let id: UUID
    let path: String
    let changedAt: Date
    var isRead: Bool

    var displayName: String {
        (path as NSString).lastPathComponent
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d HH:mm:ss"
        return formatter.string(from: changedAt)
    }
}
