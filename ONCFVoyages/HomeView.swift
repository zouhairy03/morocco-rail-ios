//
//  HomeView.swift
//  Search trains + quick info. Entry point of the booking flow.
//

import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var from = "Casa-Voyageurs"
    @State private var to = "Tanger-Ville"
    @State private var date = Date()
    @State private var passengers = 1
    @State private var trip: TripKind = .round
    @State private var go = false
    @AppStorage("serviceAlertsEnabled") private var serviceAlerts = true
    @ObservedObject private var loc = LocationManager.shared
    @State private var didAutoSetFrom = false
    @State private var nearestKm: Double?
    @State private var nearestName: String?

    /// Closest station to the phone (name + distance in km).
    private func nearestStation() -> (name: String, km: Double)? {
        guard let here = loc.location else { return nil }
        var best: (String, Double)?
        for s in store.stations {
            guard let c = StationGeo.coordinate(s.name) else { continue }
            let d = here.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude)) / 1000
            if best == nil || d < best!.1 { best = (s.name, d) }
        }
        return best
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if serviceAlerts && !store.serviceAlerts.isEmpty { serviceBanner }
                    searchCard
                    shortcuts
                    nextDepartures
                    destinations
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .background(Brand.sand.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        LogoMark(size: 26)
                        Text("ONCF ").font(.system(.headline, design: .rounded).weight(.bold)).foregroundColor(Brand.label)
                        + Text("voyages").font(.system(.headline, design: .rounded)).foregroundColor(Brand.clay)
                    }
                }
            }
            .navigationDestination(isPresented: $go) {
                if let f = store.station(from), let t = store.station(to) {
                    ResultsView(from: f, to: t, date: date, trip: trip, passengers: passengers)
                }
            }
            .onAppear { loc.startIfAuthorized() }   // never prompts; uses location only if already granted
            .onChange(of: loc.location) { _ in
                // First location fix → default the departure to the nearest station.
                guard !didAutoSetFrom, let n = nearestStation() else { return }
                didAutoSetFrom = true
                nearestKm = n.km
                nearestName = n.name
                if n.name != to { from = n.name }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: L("Le Maroc à grande vitesse"))
            Text("\(L("Où allez-vous,"))\n\(store.memberName.split(separator: " ").first.map(String.init) ?? "voyageur") ?")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.label)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private var serviceBanner: some View {
        VStack(spacing: 10) {
            ForEach(store.serviceAlerts) { a in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: a.severity.icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(bannerTint(a.severity))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(a.line).font(.caption.weight(.bold)).foregroundStyle(Brand.label)
                        Text(a.message).font(.caption).foregroundStyle(Brand.textSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(bannerTint(a.severity).opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(bannerTint(a.severity).opacity(0.25)))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func bannerTint(_ s: ServiceAlert.Severity) -> Color {
        switch s {
        case .info: return Brand.orange
        case .warning: return Color(hex: 0xE0900A)
        case .critical: return .red
        }
    }

    private var searchCard: some View {
        Card {
            VStack(spacing: 14) {
                Picker("", selection: $trip) {
                    ForEach(TripKind.allCases) { Text($0.localized).tag($0) }
                }
                .pickerStyle(.segmented)

                cityField(label: L("Départ"), selection: $from, dot: Brand.textSoft)
                if let km = nearestKm, from == nearestName {
                    let d = km < 1 ? String(format: "%.0f m", km * 1000) : String(format: "%.0f km", km)
                    Label(String(format: L("Gare la plus proche · %@ de vous"), d), systemImage: "location.fill")
                        .font(.caption2).foregroundStyle(Brand.clay)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ZStack {
                    Divider()
                    Button {
                        let t = from; from = to; to = t
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Brand.orange, in: Circle())
                    }
                    .accessibilityLabel(Text("Inverser départ et arrivée"))
                }
                cityField(label: L("Arrivée"), selection: $to, dot: Brand.orange)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Date").uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
                        DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                            .labelsHidden()
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Voyageurs").uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
                        HStack(spacing: 12) {
                            stepButton("minus", enabled: passengers > 1) { passengers -= 1 }
                            Text("\(passengers)")
                                .font(.system(.body, design: .rounded).weight(.bold))
                                .foregroundStyle(Brand.label).frame(minWidth: 18)
                                .contentTransition(.numericText())
                            stepButton("plus", enabled: passengers < 9) { passengers += 1 }
                        }
                    }
                }

                Button {
                    go = true
                } label: {
                    HStack { Text(L("Rechercher mon train")); Image(systemName: "arrow.right") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(from == to)
            }
        }
    }

    private func cityField(label: String, selection: Binding<String>, dot: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(dot).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
                Menu {
                    ForEach(store.stations) { s in
                        Button(s.name) { selection.wrappedValue = s.name }
                    }
                } label: {
                    HStack {
                        Text(selection.wrappedValue)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(Brand.label)
                        Image(systemName: "chevron.down").font(.caption2).foregroundStyle(Brand.textSoft)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(Brand.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private var shortcuts: some View {
        if !store.favorites.isEmpty || !store.recents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(store.favorites.isEmpty ? L("Trajets récents") : L("Mes trajets")).sectionTitle()
                    Spacer()
                    Button {
                        store.toggleFavorite(from: from, to: to)
                    } label: {
                        Label(store.isFavorite(from: from, to: to) ? L("Enregistré") : L("Enregistrer"),
                              systemImage: store.isFavorite(from: from, to: to) ? "star.fill" : "star")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Brand.orange)
                    }
                    .disabled(from == to)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.favorites) { r in routeChip(r, favorite: true) }
                        ForEach(store.recents.filter { rec in !store.favorites.contains { $0.from == rec.from && $0.to == rec.to } }) { r in
                            routeChip(r, favorite: false)
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
        }
    }

    private func routeChip(_ r: RouteShortcut, favorite: Bool) -> some View {
        Button {
            from = r.from; to = r.to; go = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: favorite ? "star.fill" : "clock")
                    .font(.caption2).foregroundStyle(favorite ? Brand.orange : Brand.textSoft)
                Text("\(r.from) → \(r.to)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.label)
            }
            .padding(.vertical, 10).padding(.horizontal, 14)
            .background(Brand.cream, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private var nextDepartures: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Prochains départs")).sectionTitle()
            if let f = store.station(from), let t = store.station(to) {
                ForEach(store.journeys(from: f, to: t, on: date).prefix(3)) { j in
                    NavigationLink {
                        BookingFlow(outbound: j, trip: trip, passengers: passengers, date: date)
                    } label: {
                        JourneyRow(journey: j)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var destinations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Destinations populaires")).sectionTitle()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    destinationCard("Marrakech", "La ville rouge", "Marrakech")
                    destinationCard("Tanger", "La porte du nord", "TangierStation")
                    destinationCard("Fès", "La cité impériale", "Fes")
                    destinationCard("Casablanca", "La métropole", "CasaStation")
                }
                .padding(.horizontal, 2).padding(.bottom, 6)
            }
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button {
            action(); Haptics.select()
        } label: {
            Image(systemName: icon).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(enabled ? Brand.orange : Color.black.opacity(0.15), in: Circle())
        }
        .disabled(!enabled)
        .accessibilityLabel(Text(icon == "plus" ? L("Ajouter un voyageur") : L("Retirer un voyageur")))
    }

    private func destinationCard(_ city: String, _ sub: String, _ image: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fill)
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(city)).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(.white)
                Text(L(sub)).font(.caption).foregroundStyle(.white.opacity(0.9))
            }
            .padding(14)
        }
        .frame(width: 170, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Brand.ink.opacity(0.15), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
    }
}

struct JourneyRow: View {
    let journey: Journey
    var body: some View {
        Card(padding: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(Fmt.time.string(from: journey.depart))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        Image(systemName: "arrow.right").font(.caption).foregroundStyle(Brand.textSoft)
                        Text(Fmt.time.string(from: journey.arrive))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(Brand.label)
                    HStack(spacing: 8) {
                        TypePill(type: journey.type)
                        Text("\(journey.seatsLeft) places").font(.caption2).foregroundStyle(Brand.textSoft)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("dès").font(.system(size: 9)).foregroundStyle(Brand.textSoft)
                    Text(Fmt.price(journey.basePrice))
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Brand.label)
                    Text(journey.durationText).font(.caption2).foregroundStyle(Brand.textSoft)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(journey.type.rawValue), départ \(Fmt.time.string(from: journey.depart)), arrivée \(Fmt.time.string(from: journey.arrive)), \(journey.durationText), \(journey.seatsLeft) places, à partir de \(journey.basePrice) dirhams"))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview { HomeView().environmentObject(AppStore()) }
