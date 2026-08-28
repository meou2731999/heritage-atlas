import Foundation
import UserNotifications
import HeritageAtlasCore

enum MemorialReminderScheduler {
    static func refresh(events: [FamilyCalendarEvent], enabled: Bool, locale: KinshipLocale = .en) async {
        let center = UNUserNotificationCenter.current()
        if enabled == false {
            center.removeAllPendingNotificationRequests()
            return
        }
        let granted = await requestPermission()
        guard granted else {
            center.removeAllPendingNotificationRequests()
            return
        }
        center.removeAllPendingNotificationRequests()
        for event in events.prefix(64) {
            let content = UNMutableNotificationContent()
            content.title = event.kind.localizedName(locale)
            content.body = event.subtitle
            content.sound = .default
            var date = DateComponents()
            date.calendar = Calendar(identifier: .gregorian)
            date.month = event.month
            date.day = event.day
            date.hour = 9
            date.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let identifier = "memorial.\(event.kind.rawValue).\(event.personID?.uuidString ?? event.id.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }
}
