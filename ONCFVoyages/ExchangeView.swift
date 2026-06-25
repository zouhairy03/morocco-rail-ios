//
//  ExchangeView.swift
//  Échange — change a ticket's train/date, settling the fare difference + fee.
//

import SwiftUI

struct ExchangeView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let ticket: Ticket

    @State private var date: Date
    @State private var journeys: [Journey] = []
    @State private var loading = true
    @State private var error: String?
    @State private var selected: Journey?

    init(ticket: Ticket) {
        self.ticket = ticket
        _date = State(initialValue: ticket.outbound.depart)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BILLET ACTUEL").font(.system(size: 10, weight: .bold)).foregroundStyle(Brand.textSoft)
                        Text("\(ticket.outbound.from.name) → \(ticket.outbound.to.name)")
                            .font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(Brand.label)
                        Text("\(Fmt.dayLong.string(from: ticket.outbound.depart)) · \(Fmt.time.string(from: ticket.outbound.depart)) · \(ticket.travelers.count) voy.")
                            .font(.caption).foregroundStyle(Brand.textSoft)
                        DatePicker("Nouvelle date", selection: $date, in: Date()..., displayedComponents: .date)
                            .font(.subheadline).padding(.top, 4)
                    }
                }

                Text("Nouveaux trains · frais d'échange \(Fmt.price(store.exchangeFee))")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.label)

                if loading {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
                } else if let error {
                    Text(error).font(.subheadline).foregroundStyle(Brand.textSoft)
                } else {
                    ForEach(journeys) { j in
                        Button { selected = j } label: { exchangeRow(j) }.buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
        }
        .background(Brand.sand.ignoresSafeArea())
        .navigationTitle("Échanger le billet")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: date.timeIntervalSince1970) { await load() }
        .confirmationDialog("Confirmer l'échange", isPresented: Binding(
            get: { selected != nil }, set: { if !$0 { selected = nil } }), presenting: selected) { j in
            Button("Échanger · payer \(Fmt.price(extra(for: j)))") { confirm(j) }
            Button("Annuler", role: .cancel) {}
        } message: { j in
            Text("Nouveau départ \(Fmt.time.string(from: j.depart)). Différence \(Fmt.price(max(0, newTotal(j) - ticket.total))) + frais \(Fmt.price(store.exchangeFee)).")
        }
    }

    private func exchangeRow(_ j: Journey) -> some View {
        Card(padding: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(Fmt.time.string(from: j.depart)).font(.system(.title3, design: .rounded).weight(.bold))
                        Image(systemName: "arrow.right").font(.caption).foregroundStyle(Brand.textSoft)
                        Text(Fmt.time.string(from: j.arrive)).font(.system(.title3, design: .rounded).weight(.bold))
                    }.foregroundStyle(Brand.label)
                    TypePill(type: j.type)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    let d = extra(for: j)
                    Text(d == store.exchangeFee ? "+\(Fmt.price(d))" : "+\(Fmt.price(d))")
                        .font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(Brand.label)
                    Text("à payer").font(.caption2).foregroundStyle(Brand.textSoft)
                }
            }
        }
    }

    private func newTotal(_ j: Journey) -> Int {
        let legs = j.basePrice + (ticket.returnTrip?.basePrice ?? 0)
        let units = ticket.travelers.reduce(0.0) { $0 + $1.type.factor }
        return Int((Double(legs) * units * ticket.fareClass.multiplier * (1 - ticket.discount.reduction)).rounded())
    }
    private func extra(for j: Journey) -> Int { max(0, newTotal(j) - ticket.total) + store.exchangeFee }

    private func confirm(_ j: Journey) {
        let pay = extra(for: j)
        store.exchange(ticket, to: j)
        if pay > 0 {
            store.addInvoice(InvoiceFactory.make(ticketRef: ticket.reference, amount: pay,
                                                 method: .card, payer: ticket.passengerName, authCode: "ECHANGE"))
        }
        dismiss()
    }

    private func load() async {
        loading = true; error = nil
        do {
            let all = try await store.search(from: ticket.outbound.from, to: ticket.outbound.to, on: date)
            journeys = all.filter { $0.depart > Date().addingTimeInterval(-60) && $0.id != ticket.outbound.id }
        } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Chargement impossible." }
        loading = false
    }
}
