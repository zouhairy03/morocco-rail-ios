//
//  StationGeo.swift
//  Geographic coordinates for stations — kept separate from the Codable `Station`
//  model so persisted tickets keep decoding unchanged.
//

import CoreLocation

enum StationGeo {
    /// Station coordinates keyed by station name.
    static let table: [String: CLLocationCoordinate2D] = [
        // Casablanca
        "Casa-Voyageurs": .init(latitude: 33.5883, longitude: -7.6114),
        "Casa-Port":      .init(latitude: 33.5996, longitude: -7.6090),
        "Casa-Oasis":     .init(latitude: 33.5614, longitude: -7.6589),
        "Aïn Sebaâ":      .init(latitude: 33.6076, longitude: -7.5286),
        "Mohammedia":     .init(latitude: 33.6861, longitude: -7.3866),
        // Rabat / Salé
        "Rabat-Agdal":    .init(latitude: 33.9939, longitude: -6.8512),
        "Rabat-Ville":    .init(latitude: 34.0142, longitude: -6.8341),
        "Salé-Ville":     .init(latitude: 34.0390, longitude: -6.7989),
        // North
        "Kénitra":        .init(latitude: 34.2610, longitude: -6.5802),
        "Sidi Kacem":     .init(latitude: 34.2210, longitude: -5.7070),
        "Tanger-Ville":   .init(latitude: 35.7595, longitude: -5.8340),
        // Centre / South
        "Settat":         .init(latitude: 33.0010, longitude: -7.6166),
        "Benguérir":      .init(latitude: 32.2369, longitude: -7.9527),
        "Marrakech":      .init(latitude: 31.6300, longitude: -8.0021),
        "El Jadida":      .init(latitude: 33.2316, longitude: -8.5007),
        "Safi":           .init(latitude: 32.2994, longitude: -9.2372),
        // East / interior
        "Meknès":         .init(latitude: 33.8935, longitude: -5.5473),
        "Fès":            .init(latitude: 34.0181, longitude: -5.0078),
        "Taza":           .init(latitude: 34.2100, longitude: -4.0100),
        "Oujda":          .init(latitude: 34.6814, longitude: -1.9086),
        "Nador":          .init(latitude: 35.1681, longitude: -2.9335),
        "Khouribga":      .init(latitude: 32.8811, longitude: -6.9063),
        "Béni Mellal":    .init(latitude: 32.3373, longitude: -6.3498),
        // Legacy names (older saved tickets)
        "Casablanca":     .init(latitude: 33.5883, longitude: -7.6114),
        "Rabat":          .init(latitude: 34.0142, longitude: -6.8341),
        "Tanger":         .init(latitude: 35.7595, longitude: -5.8340)
    ]

    static func coordinate(_ name: String) -> CLLocationCoordinate2D? { table[name] }
}
