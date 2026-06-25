//
//  HorairesView.swift
//  Browse timetables for any route/date (served by the networking layer).
//

import SwiftUI

struct HorairesView: View {
    @EnvironmentObject var store: AppStore
    @State private var from = "Casa-Voyageurs"
    @State private var to = "Tanger-Ville"
    @State private var date = Date()
    @State private var journeys: [Journey] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Card {
                        VStack(spacing: 12) {
                            HStack {
                                routePicker("De", selection: $from)
                                Image(systemName: "arrow.right").foregroundStyle(Brand.orange)
                                routePicker("À", selection: $to)
                            }
                            DatePicker("Date", selection: $date, in: Date()..., displayedComponents: .date)
                                .font(.subheadline)
                        }
                    }

                    if from == to {
                        note("Choisissez deux villes différentes.")
                    } else if loading {
                        VStack(spacing: 10) { ProgressView(); Text("Chargement des horaires…").font(.caption).foregroundStyle(Brand.textSoft) }
                            .frame(maxWidth: .infinity).padding(.top, 24)
                    } else if let error {
                        note(error)
                    } else {
                        Text("\(journeys.count) départs · \(Fmt.dayLong.string(from: date))")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.label)
                        ForEach(journeys) { j in
                            NavigationLink {
                                BookingFlow(outbound: j, trip: .oneWay, passengers: 1, date: date)
                            } label: { JourneyRow(journey: j) }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
            }
            .background(Brand.sand.ignoresSafeArea())
            .navigationTitle(L("Horaires"))
            .task(id: "\(from)|\(to)|\(date.timeIntervalSince1970)") { await load() }
        }
    }

    private func load() async {
        guard from != to, let f = store.station(from), let t = store.station(to) else { return }
        loading = true; error = nil
        do { journeys = try await store.search(from: f, to: t, on: date) }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Chargement impossible." }
        loading = false
    }

    private func note(_ t: String) -> some View {
        Text(t).font(.subheadline).foregroundStyle(Brand.textSoft)
            .frame(maxWidth: .infinity, alignment: .center).padding(.top, 20)
    }

    private func routePicker(_ label: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(Brand.textSoft)
            Menu {
                ForEach(store.stations) { s in Button(s.name) { selection.wrappedValue = s.name } }
            } label: {
                HStack(spacing: 4) {
                    Text(selection.wrappedValue).font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(Brand.label)
                    Image(systemName: "chevron.down").font(.caption2).foregroundStyle(Brand.textSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview { HorairesView().environmentObject(AppStore()) }
