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

    /// Push a one-off alert when the tracked train is delayed / disrupted / stopped.
    /// De-duplicated per ticket + status so the user isn't spammed.
    static func notifyDisruption(for ticket: Ticket, status: TrainStatus) {
        guard !status.isNormal else { return }
        let route = "\(ticket.outbound.from.name) → \(ticket.outbound.to.name)"
        let title: String
        let body: String
        switch status {
        case .onTime:
            return
        case .delayed(let m):
            title = L("Retard sur votre train")
            body = "\(ticket.outbound.type.rawValue) · \(route) · " + String(format: L("retard d'environ %d min"), m)
        case .disrupted(let r):
            title = L("Perturbation sur votre ligne"); body = "\(route) · \(r)"
        case .stopped(let r):
            title = L("Train arrêté"); body = "\(route) · \(r)"
        }
        let key = "disrupt-\(ticket.id.uuidString)-\(status.notifKey)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        requestAuthorization { granted in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title; content.body = body; content.sound = .default
            let req = UNNotificationRequest(identifier: key, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
            UNUserNotificationCenter.current().add(req) { _ in }
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    /// One-off "get ready, your station is approaching" alert near arrival.
    static func notifyArrivalSoon(for ticket: Ticket) {
        let key = "arrivesoon-\(ticket.id.uuidString)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        requestAuthorization { granted in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = L("Votre gare approche")
            content.body = String(format: L("Préparez-vous à descendre à %@ · voiture %d, place %@."),
                                  ticket.outbound.to.name, ticket.coach, ticket.seat)
            content.sound = .default
            let req = UNNotificationRequest(identifier: key, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
            UNUserNotificationCenter.current().add(req) { _ in }
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    /// One-off "you've reached your destination" alert.
    static func notifyArrived(for ticket: Ticket) {
        let key = "arrived-\(ticket.id.uuidString)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        requestAuthorization { granted in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = L("Vous êtes arrivé !") + " 🎉"
            content.body = String(format: L("Bienvenue à %@. Merci d'avoir voyagé avec ONCF."),
                                  ticket.outbound.to.name)
            content.sound = .default
            let req = UNNotificationRequest(identifier: key, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
            UNUserNotificationCenter.current().add(req) { _ in }
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    /// One-off "hurry up — your train is about to leave and you're not at the
    /// station yet" alert.
    static func notifyHurry(for ticket: Ticket, minutes: Int) {
        let key = "hurry-\(ticket.id.uuidString)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        requestAuthorization { granted in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = L("Dépêchez-vous !") + " 🏃"
            content.body = String(format: L("Votre train part dans %d min — rejoignez vite %@."),
                                  max(1, minutes), ticket.outbound.from.name)
            content.sound = .default
            let req = UNNotificationRequest(identifier: key, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
            UNUserNotificationCenter.current().add(req) { _ in }
            UserDefaults.standard.set(true, forKey: key)
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
