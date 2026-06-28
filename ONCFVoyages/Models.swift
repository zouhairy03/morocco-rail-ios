//
//  Models.swift
//  Core domain types for ONCF Voyages.
//

import Foundation

struct Station: Identifiable, Hashable, Codable {
    var id = UUID()
    let name: String
    let code: String   // short boarding code
    let isLGV: Bool    // served by the Al Boraq high-speed line
}

/// A network service message shown on Home (delay, works, info).
struct ServiceAlert: Identifiable, Hashable {
    enum Severity { case info, warning, critical
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
    }
    let id = UUID()
    let severity: Severity
    let line: String
    let message: String
}

/// Live operating status of a train in motion.
enum TrainStatus: Equatable {
    case onTime
    case delayed(Int)        // minutes late
    case disrupted(String)   // slow running / traffic on the line
    case stopped(String)     // halted en route

    /// Extra minutes to add to the scheduled arrival.
    var delayMinutes: Int { if case .delayed(let m) = self { return m } else { return 0 } }

    var isNormal: Bool { if case .onTime = self { return true } else { return false } }

    var isStopped: Bool { if case .stopped = self { return true } else { return false } }

    /// Stable discriminator used to de-duplicate disruption notifications.
    var notifKey: String {
        switch self {
        case .onTime: return "ontime"
        case .delayed(let m): return "delay\(m)"
        case .disrupted: return "disrupt"
        case .stopped: return "stopped"
        }
    }

    /// Human reason for disrupted / stopped states.
    var detail: String? {
        switch self {
        case .disrupted(let r), .stopped(let r): return r
        default: return nil
        }
    }

    /// French key (localised via L()).
    var titleKey: String {
        switch self {
        case .onTime:    return "À l'heure"
        case .delayed:   return "Retard"
        case .disrupted: return "Trafic perturbé"
        case .stopped:   return "Train arrêté"
        }
    }

    var icon: String {
        switch self {
        case .onTime:    return "checkmark.circle.fill"
        case .delayed:   return "clock.badge.exclamationmark.fill"
        case .disrupted: return "exclamationmark.triangle.fill"
        case .stopped:   return "exclamationmark.octagon.fill"
        }
    }
}

enum TrainType: String, Codable {
    case alBoraq = "Al Boraq"
    case alAtlas = "Al Atlas"
    case tnr     = "TNR"

    var isHighSpeed: Bool { self == .alBoraq }
    var icon: String {
        switch self {
        case .alBoraq: return "bolt.fill"
        case .alAtlas: return "tram.fill"
        case .tnr:     return "arrow.triangle.2.circlepath"
        }
    }
}

enum FareClass: String, CaseIterable, Identifiable, Codable {
    case second = "2ᵉ Confort"
    case first  = "1ʳᵉ Prestige"
    var id: String { rawValue }
    var multiplier: Double { self == .first ? 1.6 : 1.0 }
}

/// Reduction cards offered by ONCF.
enum DiscountCard: String, CaseIterable, Identifiable, Codable {
    case none   = "Sans carte"
    case jeune  = "Carte Jeune"
    case senior = "Carte Senior"
    case tarifa = "Carte Tarifa"

    var id: String { rawValue }
    var reduction: Double {
        switch self {
        case .none: return 0
        case .jeune: return 0.50
        case .senior: return 0.40
        case .tarifa: return 0.30
        }
    }
    var short: String { self == .none ? "—" : rawValue.replacingOccurrences(of: "Carte ", with: "") }
    /// Cards that can be registered & verified to the account (excludes `.none`).
    static var registrable: [DiscountCard] { [.tarifa, .jeune, .senior] }
}

/// A reduction card registered and verified against the traveller's account.
/// The discount only applies when a matching verified card is linked, and the
/// loyalty programme is tied to it (Carte Tarifa earns bonus points).
struct ReductionCard: Codable, Hashable {
    var type: DiscountCard
    var number: String
    var holder: String
    var verified: Bool
    /// Last 4 shown in the UI; the full number is never displayed.
    var masked: String { "•••• " + String(number.suffix(4)) }
}

enum TripKind: String, CaseIterable, Identifiable, Codable {
    case round = "Aller-retour"
    case oneWay = "Aller simple"
    var id: String { rawValue }
}

struct Journey: Identifiable, Hashable, Codable {
    var id = UUID()
    let from: Station
    let to: Station
    let depart: Date
    let arrive: Date
    let type: TrainType
    let basePrice: Int
    let seatsLeft: Int

    var durationMinutes: Int { max(0, Int(arrive.timeIntervalSince(depart) / 60)) }
    var durationText: String { "\(durationMinutes / 60)h\(String(format: "%02d", durationMinutes % 60))" }
}

enum PassengerType: String, CaseIterable, Identifiable, Codable {
    case adulte = "Adulte"
    case enfant = "Enfant"
    case senior = "Senior"
    var id: String { rawValue }
    /// Price factor applied to a leg's base fare.
    var factor: Double {
        switch self {
        case .adulte: return 1.0
        case .enfant: return 0.5
        case .senior: return 0.7
        }
    }
    var icon: String {
        switch self {
        case .adulte: return "person.fill"
        case .enfant: return "figure.child"
        case .senior: return "figure.walk"
        }
    }
}

struct Passenger: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var type: PassengerType
    var seat: String
}

struct Ticket: Identifiable, Hashable, Codable {
    var id = UUID()
    let reference: String
    let outbound: Journey
    let returnTrip: Journey?
    let travelers: [Passenger]
    let fareClass: FareClass
    let discount: DiscountCard
    let coach: Int
    let purchasedAt: Date

    var passengers: Int { travelers.count }
    var passengerName: String { travelers.first?.name ?? "Voyageur" }
    var seat: String { travelers.first?.seat ?? "—" }
    var isRoundTrip: Bool { returnTrip != nil }

    var total: Int {
        let legs = outbound.basePrice + (returnTrip?.basePrice ?? 0)
        let units = travelers.reduce(0.0) { $0 + $1.type.factor }
        return Int((Double(legs) * units * fareClass.multiplier * (1 - discount.reduction)).rounded())
    }
}

/// A saved or recently searched route (stored by station name to stay stable across launches).
struct RouteShortcut: Identifiable, Hashable, Codable {
    var id = UUID()
    let from: String
    let to: String
}

// MARK: - Formatting helpers

enum Fmt {
    static let time: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "HH:mm"; return f
    }()
    static let dayLong: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "EEE d MMM"; return f
    }()
    static func price(_ v: Int) -> String { "\(v) DH" }
}
