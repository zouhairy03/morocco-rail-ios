//
//  AppStore.swift
//  Observable app state: stations, journey search, bookings, favorites, persistence.
//

import Foundation
import Combine

final class AppStore: ObservableObject {
    @Published var tickets: [Ticket] = [] { didSet { persist() } }
    @Published var favorites: [RouteShortcut] = [] { didSet { persist() } }
    @Published var recents: [RouteShortcut] = [] { didSet { persist() } }
    @Published var loyaltyPoints: Int = 0 { didSet { persist() } }
    /// True right after a brand-new account is created — drives the how-to tutorial.
    @Published var showTutorial = false
    @Published var voucherDH: Int = 0 { didSet { persist() } }   // redeemed discount balance
    @Published var invoices: [Invoice] = [] { didSet { persist() } }
    /// Remembered cards (masked: brand + last 4 + expiry only — never the full PAN/CVV).
    @Published var savedCards: [SavedCard] = [] { didSet { persist() } }
    /// The traveller's verified reduction card (Tarifa / Jeune / Senior), if linked.
    @Published var reductionCard: ReductionCard? { didSet { persist() } }
    /// Live network service messages (demo feed; swap for the ONCF status API).
    @Published var serviceAlerts: [ServiceAlert] = [
        ServiceAlert(severity: .warning, line: "Al Boraq · Casablanca–Tanger",
                     message: "Trafic dense · ralentissement ~8 min entre Kénitra et Tanger."),
        ServiceAlert(severity: .warning, line: "Al Atlas · Casa–Marrakech",
                     message: "Ralentissements ~15 min suite à des travaux près de Settat.")
    ]
    var memberName = "Youssef Zouhair"

    private lazy var trainAPI = TrainAPI(client: APIClient(baseURL: AppConfig.baseURL))

    // Real ONCF network — several stations per city where they exist.
    let stations: [Station] = [
        // Casablanca
        Station(name: "Casa-Voyageurs", code: "CASV", isLGV: true),
        Station(name: "Casa-Port",      code: "CASP", isLGV: false),
        Station(name: "Casa-Oasis",     code: "CASO", isLGV: false),
        Station(name: "Aïn Sebaâ",      code: "ASB",  isLGV: false),
        Station(name: "Mohammedia",     code: "MOH",  isLGV: false),
        // Rabat / Salé
        Station(name: "Rabat-Agdal",    code: "RAG",  isLGV: true),
        Station(name: "Rabat-Ville",    code: "RBV",  isLGV: false),
        Station(name: "Salé-Ville",     code: "SLE",  isLGV: false),
        // North
        Station(name: "Kénitra",        code: "KEN",  isLGV: true),
        Station(name: "Sidi Kacem",     code: "SKC",  isLGV: false),
        Station(name: "Tanger-Ville",   code: "TNG",  isLGV: true),
        // Centre / South
        Station(name: "Settat",         code: "SET",  isLGV: false),
        Station(name: "Benguérir",      code: "BGR",  isLGV: false),
        Station(name: "Marrakech",      code: "RAK",  isLGV: false),
        Station(name: "El Jadida",      code: "JAD",  isLGV: false),
        Station(name: "Safi",           code: "SAF",  isLGV: false),
        // East / interior
        Station(name: "Meknès",         code: "MEK",  isLGV: false),
        Station(name: "Fès",            code: "FES",  isLGV: false),
        Station(name: "Taza",           code: "TAZ",  isLGV: false),
        Station(name: "Oujda",          code: "OUJ",  isLGV: false),
        Station(name: "Nador",          code: "NDR",  isLGV: false),
        Station(name: "Khouribga",      code: "KHG",  isLGV: false),
        Station(name: "Béni Mellal",    code: "BEM",  isLGV: false)
    ]

    private var loading = false
    /// The signed-in account whose data is currently loaded (nil = no one).
    private var currentUserID: String?

    init() {
        // Data is per-account; it loads in `activate(...)` once a user signs in.
    }

    // MARK: Per-account session

    /// Load (or create) the data belonging to a specific account. Each e-mail
    /// gets its own isolated dashboard — tickets, loyalty, cards, etc.
    func activate(userID: String, name: String) {
        memberName = name.isEmpty ? "Voyageur" : name
        guard userID != currentUserID else { return }
        currentUserID = userID
        loadCurrentUser()
    }

    /// Clear the in-memory dashboard on sign-out so the next account starts clean.
    func signOutData() {
        currentUserID = nil
        loading = true
        tickets = []; favorites = []; recents = []; invoices = []
        savedCards = []; reductionCard = nil
        loyaltyPoints = 0; voucherDH = 0
        showTutorial = false
        loading = false
    }

    private func loadCurrentUser() {
        loading = true
        tickets = []; favorites = []; recents = []; invoices = []
        savedCards = []; reductionCard = nil
        loyaltyPoints = 0; voucherDH = 0
        var isNew = true
        if let data = try? Data(contentsOf: fileURL),
           let s = try? JSONDecoder().decode(Persisted.self, from: data) {
            // Returning account → restore its own data (strip any legacy demo ticket).
            isNew = false
            tickets = s.tickets.filter { $0.reference != "ONCF-7K3Q8X" }
            favorites = s.favorites; recents = s.recents
            loyaltyPoints = s.points; invoices = s.invoices ?? []; voucherDH = s.voucher ?? 0
            savedCards = s.cards ?? []; reductionCard = s.reduction
        }
        showTutorial = isNew                 // tutorial only for brand-new accounts
        loading = false
        persist()                            // save cleaned state / create the empty file
    }

    func station(_ name: String) -> Station? { stations.first { $0.name == name } }

    /// The ticket to show on the live-tracking tab: one in transit now, else the
    /// soonest upcoming, else the most recent.
    var trackedTicket: Ticket? {
        let now = Date()
        if let live = tickets.first(where: { $0.outbound.depart <= now && now <= $0.outbound.arrive }) {
            return live
        }
        let upcoming = tickets.filter { $0.outbound.depart > now }
            .sorted { $0.outbound.depart < $1.outbound.depart }
        return upcoming.first ?? tickets.first
    }

    // MARK: Live train status

    /// Operating status for a tracked train, derived from the current service
    /// alerts (swap `serviceAlerts` for the ONCF status API to make it real).
    func liveStatus(for ticket: Ticket) -> TrainStatus {
        let t = ticket.outbound
        let line = t.type.rawValue
        let from = t.from.name, to = t.to.name
        guard let alert = serviceAlerts.first(where: {
            $0.line.contains(line) || $0.line.contains(from) || $0.line.contains(to)
        }) else { return .onTime }

        switch alert.severity {
        case .info:
            return .onTime
        case .warning:
            if let mins = Self.minutes(in: alert.message) { return .delayed(mins) }
            return .disrupted(alert.message)
        case .critical:
            return .stopped(alert.message)
        }
    }

    /// Pull a "~8 min" style figure out of an alert message.
    private static func minutes(in text: String) -> Int? {
        guard let r = text.range(of: #"(\d+)\s*min"#, options: .regularExpression) else { return nil }
        return Int(text[r].filter(\.isNumber))
    }

    // MARK: Async search (networking layer; live or mock)

    func search(from: Station, to: Station, on date: Date) async throws -> [Journey] {
        if AppConfig.useLiveAPI {
            return try await trainAPI.searchJourneys(from: from, to: to, on: date) { [weak self] code in
                self?.stations.first { $0.code == code }
            }
        }
        // Mock path: simulate network latency so loading states are real.
        try? await Task.sleep(nanoseconds: 450_000_000)
        return journeys(from: from, to: to, on: date)
    }

    func addInvoice(_ invoice: Invoice) { invoices.insert(invoice, at: 0) }

    /// Remember a card (deduplicated by brand + last 4).
    func saveCard(_ card: SavedCard) {
        guard !savedCards.contains(where: { $0.brand == card.brand && $0.last4 == card.last4 }) else { return }
        savedCards.insert(card, at: 0)
    }
    func removeCard(_ card: SavedCard) { savedCards.removeAll { $0.id == card.id } }

    // MARK: Reduction card (verify + link)

    /// Verify and link a reduction card. Verification is mocked (a real backend
    /// would check the card against ONCF's loyalty system). Returns the result.
    func linkReductionCard(type: DiscountCard, number: String, holder: String) async -> Bool {
        let digits = number.filter(\.isNumber)
        let name = holder.trimmingCharacters(in: .whitespaces)
        guard digits.count >= 6, !name.isEmpty else { return false }
        try? await Task.sleep(nanoseconds: 700_000_000)   // simulate the verification call
        reductionCard = ReductionCard(type: type, number: digits, holder: name, verified: true)
        return true
    }
    func removeReductionCard() { reductionCard = nil }

    // MARK: Loyalty redemption

    /// Spend points for a discount voucher. Returns false if not enough points.
    @discardableResult
    func redeem(cost: Int, voucher: Int) -> Bool {
        guard loyaltyPoints >= cost else { return false }
        loyaltyPoints -= cost
        voucherDH += voucher
        return true
    }
    func useVoucher(_ amount: Int) { voucherDH = max(0, voucherDH - amount) }

    // MARK: Journey search (local generator / mock source)

    func journeys(from: Station, to: Station, on date: Date) -> [Journey] {
        guard from != to else { return [] }
        let info = routeInfo(from, to)
        let slots = [(6, 40), (8, 35), (10, 10), (12, 35), (15, 5), (17, 40), (19, 25)]
        let seats = [3, 8, 15, 5, 9, 2, 18]
        let cal = Calendar.current
        return slots.enumerated().map { (i, hm) in
            let dep = cal.date(bySettingHour: hm.0, minute: hm.1, second: 0, of: date) ?? date
            let dur = info.dur + (i % 3) * 5
            let arr = dep.addingTimeInterval(Double(dur * 60))
            let peak = (i >= 2 && i <= 4) ? 1.18 : 1.0
            let price = Int((Double(info.base) * peak / 10).rounded()) * 10 - 1
            return Journey(from: from, to: to, depart: dep, arrive: arr,
                           type: info.type, basePrice: price, seatsLeft: seats[i])
        }
    }

    private func routeInfo(_ a: Station, _ b: Station) -> (dur: Int, type: TrainType, base: Int) {
        let key = [a.name, b.name].sorted().joined(separator: "|")
        let table: [String: Int] = [
            "Casa-Voyageurs|Tanger-Ville": 130, "Casa-Voyageurs|Rabat-Agdal": 50,
            "Casa-Voyageurs|Kénitra": 70, "Casa-Voyageurs|Marrakech": 165,
            "Casa-Voyageurs|Fès": 215, "Casa-Voyageurs|Meknès": 190,
            "Casa-Voyageurs|Oujda": 340, "Rabat-Agdal|Tanger-Ville": 75,
            "Fès|Rabat-Agdal": 150, "Fès|Tanger-Ville": 230,
            "Casa-Voyageurs|El Jadida": 95, "Marrakech|Tanger-Ville": 290, "Fès|Marrakech": 430,
            "Kénitra|Tanger-Ville": 60, "Fès|Meknès": 40, "Mohammedia|Rabat-Agdal": 35
        ]
        var dur = table[key]
        if dur == nil {
            var h = 7
            for ch in key.unicodeScalars { h = (h &* 31 &+ Int(ch.value)) % 100_000 }
            dur = 80 + (h % 230)
        }
        let lgv = a.isLGV && b.isLGV
        let base = lgv ? 149 : max(69, (dur! * 7 / 10) / 10 * 10 - 1)
        return (dur!, lgv ? .alBoraq : .alAtlas, base)
    }

    // MARK: Booking

    @discardableResult
    func book(outbound: Journey, returnTrip: Journey?, travelers: [Passenger], fareClass: FareClass,
              discount: DiscountCard, coach: Int) -> Ticket {
        let ref = "ONCF-" + String(UUID().uuidString.prefix(6)).uppercased()
        let ticket = Ticket(reference: ref, outbound: outbound, returnTrip: returnTrip,
                            travelers: travelers, fareClass: fareClass, discount: discount,
                            coach: coach, purchasedAt: Date())
        tickets.insert(ticket, at: 0)
        // Loyalty points are earned only with a linked reduction card; Carte Tarifa earns 1.5×.
        if let rc = reductionCard, rc.verified {
            let base = ticket.total / 10
            loyaltyPoints += rc.type == .tarifa ? Int(Double(base) * 1.5) : base
        }
        addRecent(from: outbound.from.name, to: outbound.to.name)
        return ticket
    }

    // MARK: Refund & exchange policy

    /// Refund depends on how long before departure the cancellation happens.
    func refundQuote(for ticket: Ticket) -> (refund: Int, fee: Int, label: String) {
        let hours = ticket.outbound.depart.timeIntervalSinceNow / 3600
        let rate: Double = hours >= 24 ? 0 : (hours >= 1 ? 0.10 : 1.0)
        let fee = Int((Double(ticket.total) * rate).rounded())
        let label = rate == 0 ? "Remboursement intégral (plus de 24h avant le départ)"
            : (rate >= 1 ? "Non remboursable — départ imminent (moins d'1h)"
               : "Frais d'annulation de 10% (moins de 24h avant le départ)")
        return (ticket.total - fee, fee, label)
    }

    /// Flat fee charged to change a train/date.
    let exchangeFee = 30

    func cancel(_ ticket: Ticket) {
        NotificationService.cancelReminder(for: ticket)
        tickets.removeAll { $0.id == ticket.id }
        loyaltyPoints = max(0, loyaltyPoints - ticket.total / 10)
    }

    /// Replace a ticket's outbound train (échange). Returns the difference to settle.
    @discardableResult
    func exchange(_ ticket: Ticket, to newOutbound: Journey) -> Ticket {
        var updated = Ticket(reference: ticket.reference, outbound: newOutbound,
                             returnTrip: ticket.returnTrip, travelers: ticket.travelers,
                             fareClass: ticket.fareClass, discount: ticket.discount,
                             coach: ticket.coach, purchasedAt: ticket.purchasedAt)
        updated.id = ticket.id
        if let i = tickets.firstIndex(where: { $0.id == ticket.id }) { tickets[i] = updated }
        return updated
    }

    // MARK: Favorites & recents

    func isFavorite(from: String, to: String) -> Bool {
        favorites.contains { $0.from == from && $0.to == to }
    }
    func toggleFavorite(from: String, to: String) {
        if let i = favorites.firstIndex(where: { $0.from == from && $0.to == to }) {
            favorites.remove(at: i)
        } else {
            favorites.insert(RouteShortcut(from: from, to: to), at: 0)
        }
    }
    func addRecent(from: String, to: String) {
        recents.removeAll { $0.from == from && $0.to == to }
        recents.insert(RouteShortcut(from: from, to: to), at: 0)
        if recents.count > 6 { recents = Array(recents.prefix(6)) }
    }

    // MARK: Persistence

    private struct Persisted: Codable {
        var tickets: [Ticket]; var favorites: [RouteShortcut]; var recents: [RouteShortcut]
        var points: Int; var invoices: [Invoice]?; var voucher: Int?; var cards: [SavedCard]?
        var reduction: ReductionCard?
    }
    /// One file per account so each e-mail has an isolated dashboard.
    private var fileURL: URL {
        let id = currentUserID ?? "guest"
        let safe = String(id.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? Character($0) : "_"
        })
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("oncf_state_\(safe).json")
    }
    private func persist() {
        guard !loading else { return }
        let state = Persisted(tickets: tickets, favorites: favorites, recents: recents,
                              points: loyaltyPoints, invoices: invoices, voucher: voucherDH,
                              cards: savedCards, reduction: reductionCard)
        if let data = try? JSONEncoder().encode(state) { try? data.write(to: fileURL) }
    }
}
