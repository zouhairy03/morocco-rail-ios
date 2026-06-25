//
//  Backend.swift
//  Networking layer + train service abstraction.
//
//  The app ships with a Mock data path (works offline, used by default).
//  Flip `AppConfig.useLiveAPI = true` and set `AppConfig.baseURL` to ONCF's real
//  timetable/booking API and the same UI is served by `TrainAPI` over HTTPS.
//

import Foundation

// MARK: - Configuration

enum AppConfig {
    /// Toggle to route the app through the real ONCF backend instead of on-device mock data.
    static var useLiveAPI = false
    /// TODO: replace with ONCF's production API base URL once available.
    static let baseURL = URL(string: "https://api.oncf-voyages.ma/v1")!
}

// MARK: - Networking

enum APIError: LocalizedError {
    case badURL
    case http(Int)
    case decoding
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Adresse du service invalide."
        case .http(let c): return "Le service a répondu (\(c)). Réessayez."
        case .decoding: return "Réponse illisible du service."
        case .transport(let m): return "Connexion impossible : \(m)"
        }
    }
}

struct APIClient {
    let baseURL: URL
    var session: URLSession = .shared

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        comps?.queryItems = query.isEmpty ? nil : query
        guard let url = comps?.url else { throw APIError.badURL }

        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw APIError.transport("réponse invalide") }
            guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
            do {
                let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
                return try dec.decode(T.self, from: data)
            } catch { throw APIError.decoding }
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }
}

// MARK: - Train service (live path)

private struct JourneyDTO: Decodable {
    let from: String          // station code
    let to: String
    let depart: Date
    let arrive: Date
    let type: String
    let price: Int
    let seatsLeft: Int
}

struct TrainAPI {
    let client: APIClient

    /// Fetch journeys from the live backend. `resolve` maps a station code to a known Station.
    func searchJourneys(from: Station, to: Station, on date: Date,
                        resolve: (String) -> Station?) async throws -> [Journey] {
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withFullDate]
        let query = [
            URLQueryItem(name: "from", value: from.code),
            URLQueryItem(name: "to", value: to.code),
            URLQueryItem(name: "date", value: iso.string(from: date))
        ]
        let dtos: [JourneyDTO] = try await client.get("journeys", query: query)
        return dtos.compactMap { dto in
            guard let f = resolve(dto.from), let t = resolve(dto.to) else { return nil }
            return Journey(from: f, to: t, depart: dto.depart, arrive: dto.arrive,
                           type: TrainType(rawValue: dto.type) ?? .alAtlas,
                           basePrice: dto.price, seatsLeft: dto.seatsLeft)
        }
    }
}
