//
//  LocationManager.swift
//  Phone location for live train tracking (shows the user on the map and their
//  distance to the train / next station).
//

import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// Shared instance so every screen reuses one permission grant and one fix.
    static let shared = LocationManager()

    @Published var location: CLLocation?
    @Published var authorized = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Ask for "when in use" permission (shows the system dialog if undecided)
    /// and start updates. Call this from an *in-context* screen — e.g. Tracking.
    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            authorized = true
            manager.startUpdatingLocation()
        default:
            authorized = false
        }
    }

    /// Start updates ONLY if permission was already granted — never shows the
    /// dialog. Use on screens that merely benefit from location (e.g. Home), so
    /// the prompt doesn't fire during onboarding.
    func startIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorized = true
            manager.startUpdatingLocation()
        default:
            break   // do not prompt
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        Task { @MainActor in
            switch m.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                authorized = true
                m.startUpdatingLocation()
            default:
                authorized = false
            }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        Task { @MainActor in self.location = loc }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}

    /// Distance in km from the phone to a coordinate (nil if no fix yet).
    func distanceKm(to coord: CLLocationCoordinate2D) -> Double? {
        guard let here = location else { return nil }
        let there = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return here.distance(from: there) / 1000
    }
}
