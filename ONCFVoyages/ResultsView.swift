//
//  ResultsView.swift
//  Journey results (via the networking layer) + the booking flow with
//  per-passenger details, seat selection, payment and invoice.
//

import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var store: AppStore
    let from: Station, to: Station
    let date: Date
    let trip: TripKind
    let passengers: Int

    @State private var journeys: [Journey] = []
    @State private var loading = true
    @State private var error: String?
    @State private var sort: SortKey = .heure
    @State private var alBoraqOnly = false

    enum SortKey: String, CaseIterable, Identifiable {
        case heure = "Heure", prix = "Prix", duree = "Durée"
        var id: String { rawValue }
    }

    private var displayed: [Journey] {
        var j = alBoraqOnly ? journeys.filter { $0.type == .alBoraq } : journeys
        switch sort {
        case .heure: j.sort { $0.depart < $1.depart }
        case .prix:  j.sort { $0.basePrice < $1.basePrice }
        case .duree: j.sort { $0.durationMinutes < $1.durationMinutes }
        }
        return j
    }

    var body: some View {
        Group {
            if loading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(L("Recherche des trains…")).font(.subheadline).foregroundStyle(Brand.textSoft)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 40)).foregroundStyle(Brand.textSoft)
                    Text(error).font(.subheadline).foregroundStyle(Brand.textSoft).multilineTextAlignment(.center)
                    Button(L("Réessayer")) { Task { await load() } }.buttonStyle(PrimaryButtonStyle(block: false))
                }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if journeys.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tram").font(.system(size: 40)).foregroundStyle(Brand.textSoft)
                    Text(L("Aucun train pour cette date.")).font(.subheadline).foregroundStyle(Brand.textSoft)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        filterBar
                        ForEach(displayed) { j in
                            NavigationLink {
                                BookingFlow(outbound: j, trip: trip, passengers: passengers, date: date)
                            } label: { JourneyRow(journey: j) }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .background(Brand.sand.ignoresSafeArea())
        .navigationTitle("\(from.name) → \(to.name)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("", selection: $sort) {
                ForEach(SortKey.allCases) { Text(L($0.rawValue)).tag($0) }
            }
            .pickerStyle(.segmented)
            Button { alBoraqOnly.toggle() } label: {
                Label("Al Boraq", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 7).padding(.horizontal, 12)
                    .background(alBoraqOnly ? AnyShapeStyle(Brand.warm) : AnyShapeStyle(Brand.cream), in: Capsule())
                    .foregroundStyle(alBoraqOnly ? .white : Brand.textSoft)
                    .overlay(Capsule().strokeBorder(Color.black.opacity(alBoraqOnly ? 0 : 0.1)))
            }
        }
    }

    private func load() async {
        loading = true; error = nil
        do {
            let all = try await store.search(from: from, to: to, on: date)
            // hide departures already gone today
            journeys = all.filter { $0.depart > Date().addingTimeInterval(-60) }
        } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Recherche impossible." }
        loading = false
    }
}

private struct SeatEdit: Identifiable { let index: Int; var id: Int { index } }

struct BookingFlow: View {
    @EnvironmentObject var store: AppStore
    let outbound: Journey
    let trip: TripKind
    let passengers: Int
    let date: Date

    @State private var returnJourney: Journey?
    @State private var travelers: [Passenger]
    @State private var fareClass: FareClass = .second
    @State private var coach = Int.random(in: 1...8)

    /// Discount is driven solely by the verified reduction card linked to the account.
    private var discount: DiscountCard {
        guard let c = store.reductionCard, c.verified else { return .none }
        return c.type
    }
    @State private var seatEdit: SeatEdit?
    @State private var showPayment = false
    @State private var booked: Ticket?

    init(outbound: Journey, trip: TripKind, passengers: Int, date: Date) {
        self.outbound = outbound; self.trip = trip; self.passengers = passengers; self.date = date
        _travelers = State(initialValue: (0..<max(1, passengers)).map { _ in
            Passenger(name: "", type: .adulte, seat: "")
        })
    }

    private var needsReturn: Bool { trip == .round && returnJourney == nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if needsReturn {
                    Eyebrow(text: L("Choisissez votre retour"))
                    Text("\(outbound.to.name) → \(outbound.from.name)").sectionTitle()
                    ForEach(store.journeys(from: outbound.to, to: outbound.from, on: date)) { j in
                        Button { withAnimation { returnJourney = j } } label: { JourneyRow(journey: j) }
                            .buttonStyle(.plain)
                    }
                } else {
                    summary
                    travelersSection
                    optionsCard
                    payBar
                }
            }
            .padding(18)
        }
        .background(Brand.sand.ignoresSafeArea())
        .navigationTitle(needsReturn ? L("Retour") : L("Récapitulatif"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $seatEdit) { edit in
            SeatMapView(coach: coach, selection: $travelers[edit.index].seat,
                        taken: Set(travelers.enumerated()
                            .filter { $0.offset != edit.index && !$0.element.seat.isEmpty }
                            .map { $0.element.seat }))
        }
        .sheet(isPresented: $showPayment) {
            PaymentSheet(amount: total, payer: payerName) { code, method in finalize(authCode: code, method: method) }
                .environmentObject(store)
        }
        .sheet(item: $booked) { t in ConfirmationView(ticket: t) }
    }

    private var payerName: String {
        let n = travelers.first?.name.trimmingCharacters(in: .whitespaces) ?? ""
        return n.isEmpty ? store.memberName : n
    }

    private var summary: some View {
        VStack(spacing: 12) {
            legRow(outbound, label: trip == .round ? "Aller" : "Aller simple")
            if let r = returnJourney { legRow(r, label: "Retour") }
        }
    }

    private func legRow(_ j: Journey, label: String) -> some View {
        Card(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: j.type.icon)
                    .foregroundStyle(Brand.orange)
                    .frame(width: 34, height: 34)
                    .background(Brand.orange.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(j.from.name) → \(j.to.name)").font(.system(.subheadline, design: .rounded).weight(.bold))
                    Text("\(label) · \(Fmt.dayLong.string(from: j.depart)) · \(j.type.rawValue)")
                        .font(.caption2).foregroundStyle(Brand.textSoft)
                }
                Spacer()
                Text("\(Fmt.time.string(from: j.depart)) → \(Fmt.time.string(from: j.arrive))")
                    .font(.caption.weight(.semibold)).foregroundStyle(Brand.label)
            }
        }
    }

    private var travelersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voyageurs (\(travelers.count))").sectionTitle()
            ForEach(travelers.indices, id: \.self) { i in
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(L("Voyageur")) \(i + 1)").font(.headline).foregroundStyle(Brand.label)
                            Spacer()
                            Menu {
                                ForEach(PassengerType.allCases) { t in
                                    Button { travelers[i].type = t } label: {
                                        Label("\(t.rawValue)\(t == .adulte ? "" : " (−\(Int((1 - t.factor) * 100))%)")", systemImage: t.icon)
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: travelers[i].type.icon).font(.caption)
                                    Text(travelers[i].type.rawValue).font(.subheadline.weight(.semibold))
                                    Image(systemName: "chevron.down").font(.caption2)
                                }
                                .foregroundStyle(Brand.orange)
                                .padding(.vertical, 6).padding(.horizontal, 12)
                                .background(Brand.orange.opacity(0.1), in: Capsule())
                            }
                        }
                        TextField(i == 0 ? store.memberName : L("Nom du voyageur"), text: $travelers[i].name)
                            .padding(.vertical, 11).padding(.horizontal, 13)
                            .background(Brand.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Button { seatEdit = SeatEdit(index: i) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "chair.lounge.fill").foregroundStyle(Brand.orange)
                                Text(travelers[i].seat.isEmpty ? "Choisir le siège" : "Voiture \(coach) · Place \(travelers[i].seat)")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.label)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.textSoft)
                            }
                            .padding(.vertical, 11).padding(.horizontal, 13)
                            .background(Brand.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var optionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CLASSE").font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
                    Picker("", selection: $fareClass) {
                        ForEach(FareClass.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("CARTE DE RÉDUCTION").font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
                    if discount != .none, let c = store.reductionCard {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Color(hex: 0x16A34A))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(c.type.rawValue) · −\(Int(c.type.reduction * 100))%")
                                    .font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Brand.label)
                                Text("\(c.masked) · \(L("vérifiée"))").font(.caption2).foregroundStyle(Brand.textSoft)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10).padding(.horizontal, 13)
                        .background(Color(hex: 0x16A34A).opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        NavigationLink { ReductionCardView() } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill").foregroundStyle(Brand.orange)
                                Text(L("Lier une carte de réduction")).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Brand.label)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.textSoft)
                            }
                            .padding(.vertical, 11).padding(.horizontal, 13)
                            .background(Brand.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var baseTotal: Int {
        let legs = outbound.basePrice + (returnJourney?.basePrice ?? 0)
        let units = travelers.reduce(0.0) { $0 + $1.type.factor }
        return Int((Double(legs) * units * fareClass.multiplier * (1 - discount.reduction)).rounded())
    }
    private var appliedVoucher: Int { min(store.voucherDH, baseTotal) }
    private var total: Int { max(0, baseTotal - appliedVoucher) }

    private var payBar: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                if appliedVoucher > 0 {
                    HStack {
                        Label("Bon de réduction", systemImage: "gift.fill")
                            .font(.caption).foregroundStyle(Color(hex: 0x7EF0A8))
                        Spacer()
                        Text("−\(Fmt.price(appliedVoucher))").font(.caption.weight(.semibold)).foregroundStyle(Color(hex: 0x7EF0A8))
                    }
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Total")).font(.caption).foregroundStyle(.white.opacity(0.7))
                        Text("\(travelers.count) voy. · \(trip == .round ? 2 : 1) trajet(s) · \(fareClass.localized)\(discount == .none ? "" : " · \(discount.short)")")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Text(Fmt.price(total))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Brand.orange2)
                }
            }
            .padding(16)
            .background(Brand.inkGrad, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button { showPayment = true } label: {
                HStack { Image(systemName: "lock.fill"); Text("\(L("Payer")) · \(Fmt.price(total))") }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func finalize(authCode: String, method: PaymentMethod) {
        let paid = total
        let usedVoucher = appliedVoucher
        var finals = travelers
        for i in finals.indices {
            if finals[i].name.trimmingCharacters(in: .whitespaces).isEmpty {
                finals[i].name = i == 0 ? store.memberName : "Voyageur \(i + 1)"
            }
            if finals[i].seat.isEmpty {
                finals[i].seat = "\(Int.random(in: 1...28))\(["A","B","C","D"].randomElement()!)"
            }
        }
        let ticket = store.book(outbound: outbound, returnTrip: returnJourney, travelers: finals,
                                fareClass: fareClass, discount: discount, coach: coach)
        let invoice = InvoiceFactory.make(ticketRef: ticket.reference, amount: paid,
                                          method: method, payer: payerName, authCode: authCode)
        store.addInvoice(invoice)
        if usedVoucher > 0 { store.useVoucher(usedVoucher) }
        // Auto-schedule a departure reminder (asks permission the first time).
        NotificationService.scheduleReminder(for: ticket) { _ in }
        Haptics.success()
        booked = ticket
    }
}

#Preview {
    let s = AppStore()
    return NavigationStack {
        ResultsView(from: s.station("Casa-Voyageurs")!, to: s.station("Tanger-Ville")!,
                    date: Date(), trip: .round, passengers: 2)
    }.environmentObject(s)
}
