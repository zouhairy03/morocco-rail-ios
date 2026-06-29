//
//  TripActivity.swift
//  App-side Live Activity model + controller (start / update / end).
//
//  The matching widget UI lives in the ONCFWidgets extension. ActivityKit pairs
//  the two by the attributes type name + content shape, so `TripActivityAttributes`
//  is declared identically here and in the extension.
//

import Foundation
import ActivityKit

@available(iOS 16.2, *)
struct TripActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double      // 0…1 along the route (fallback / Dynamic Island)
        var departDate: Date      // drives the self-advancing lock-screen bar…
        var arriveDate: Date      // …so the train moves with no app running
        var headline: String      // e.g. "12 min until arrival"
        var statusText: String    // e.g. "On time" / "Delay +8 min"
        var stopped: Bool
        var nextStop: String      // next station name
        var nextStopTime: String  // "07:23"
        var stopFractions: [Double] // positions (0…1) of intermediate stops, for ticks
        var disruption: String    // accident / slowdown message ("" = none)
    }
    var reference: String         // ONCF-XXXX
    var from: String
    var to: String
    var line: String              // "Al Boraq"
}

/// Starts / updates / ends the lock-screen + Dynamic Island Live Activity for a
/// trip. Local updates only (no push), which works without a paid account.
@available(iOS 16.2, *)
final class TripActivityController {
    static let shared = TripActivityController()
    private var activity: Activity<TripActivityAttributes>?
    private var lastState: TripActivityAttributes.ContentState?

    var isActive: Bool { activity != nil }

    func start(reference: String, from: String, to: String, line: String,
               state: TripActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let activity {                                   // already running → just refresh
            lastState = state
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }
        let attrs = TripActivityAttributes(reference: reference, from: from, to: to, line: line)
        do {
            activity = try Activity.request(attributes: attrs,
                                            content: ActivityContent(state: state, staleDate: nil))
            lastState = state
        } catch {
            activity = nil
        }
    }

    func update(_ state: TripActivityAttributes.ContentState) {
        guard let activity, state != lastState else { return }   // dedupe — avoid spamming ActivityKit
        lastState = state
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        let final = lastState
        Task {
            if let final {
                await activity.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: .immediate)
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        self.activity = nil
        self.lastState = nil
    }
}
