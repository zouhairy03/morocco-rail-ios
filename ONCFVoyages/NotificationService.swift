//
//  NotificationService.swift
//  Local departure reminders.
//

import Foundation
import UserNotifications

enum NotificationService {
    /// User-chosen minutes before departure for the reminder (default 30).
    static var reminderLeadMinutes: Int {
        let v = UserDefaults.standard.integer(forKey: "reminderLeadMinutes")
        return v == 0 ? 30 : v
    }

    static func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    /// Current permission status (for the settings screen).
    static func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { completion(s.authorizationStatus) }
        }
    }

    /// Schedule a reminder 30 minutes before departure (or shortly from now if that is in the past — handy in the demo).
    static func scheduleReminder(for ticket: Ticket, completion: @escaping (Bool) -> Void) {
        requestAuthorization { granted in
            guard granted else { completion(false); return }
            let content = UNMutableNotificationContent()
            content.title = "Votre train approche 🚆"
            content.body = "\(ticket.outbound.from.name) → \(ticket.outbound.to.name) à "
                + Fmt.time.string(from: ticket.outbound.depart)
                + " · Voiture \(ticket.coach), place \(ticket.seat)."
            content.sound = .default

            let fire = ticket.outbound.depart.addingTimeInterval(Double(-reminderLeadMinutes) * 60)
            let interval = max(5, fire.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: "reminder-\(ticket.id)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async { completion(error == nil) }
            }
        }
    }

    static func cancelReminder(for ticket: Ticket) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["reminder-\(ticket.id)"])
    }
}

/// Lets reminders appear as a banner even while the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
