//
//  TrackView.swift
//  Live tracking of the traveller's actual next ticket.
//

import SwiftUI
import Combine
import MapKit
import CoreLocation

private struct Stop: Identifiable {
    let id = UUID()
    let name: String
    let time: Date
    let position: CGFloat
    var dwell: Int = 0   // minutes the train stops at this station (0 = terminus)
    var voie: Int = 1    // platform / track number
}

struct TrackView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var loc = LocationManager.shared
    @State private var showLocationPrimer = false
    @State private var now = Date()
    @State private var showMap = false
    @State private var liveActivityOn = false
    // Ticks once a second — the train position is derived from the real clock,
    // so it advances at the true pace of the journey (not a fast fake loop).
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Al Boraq high-speed line, south → north.
    private let lgvOrder = ["Casa-Voyageurs", "Rabat-Agdal", "Kénitra", "Tanger-Ville"]

    private var ticket: Ticket? { store.trackedTicket }

    /// Real progress 0…1 from the clock; the delay extends the effective arrival.
    private func journeyProgress(_ t: Ticket, delay: Int) -> CGFloat {
        let dep = t.outbound.depart
        let total = t.outbound.arrive.addingTimeInterval(Double(delay) * 60).timeIntervalSince(dep)
        guard total > 0 else { return 0 }
        return CGFloat(min(max(now.timeIntervalSince(dep) / total, 0), 1))
    }

    private func stops(for t: Ticket) -> [Stop] {
        let from = t.outbound.from.name, to = t.outbound.to.name
        var names: [String]
        if let fi = lgvOrder.firstIndex(of: from), let ti = lgvOrder.firstIndex(of: to) {
            names = fi <= ti ? Array(lgvOrder[fi...ti]) : Array(lgvOrder[ti...fi]).reversed()
        } else { names = [from, to] }
        let dep = t.outbound.depart
        let dur = t.outbound.arrive.timeIntervalSince(dep)
        let n = names.count
        return names.enumerated().map { (i, nm) in
            let pos = n <= 1 ? 0 : CGFloat(i) / CGFloat(n - 1)
            // Intermediate stations have a short dwell; origin & terminus don't.
            let dwell = (i == 0 || i == n - 1) ? 0 : 2
            // Stable platform number per station per trip.
            let voie = (nm + t.reference).unicodeScalars.reduce(0) { $0 + Int($1.value) } % 8 + 1
            return Stop(name: nm, time: dep.addingTimeInterval(dur * Double(pos)),
                        position: pos, dwell: dwell, voie: voie)
        }
    }

    /// Index of the next station the train will reach (for the "next stop" highlight).
    private func nextStopIndex(_ stops: [Stop], progress: CGFloat) -> Int? {
        stops.firstIndex { progress < $0.position }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let t = ticket {
                    let status = store.liveStatus(for: t)
                    let p = journeyProgress(t, delay: status.delayMinutes)
                    let mapStops = stops(for: t).compactMap { s -> RouteMapView.Stop? in
                        guard let c = StationGeo.coordinate(s.name) else { return nil }
                        return RouteMapView.Stop(id: s.name, coord: c)
                    }
                    let trainCoord = RouteMapView.interpolate(mapStops, Double(p))
                    let distKm = trainCoord.flatMap { loc.distanceKm(to: $0) }
                    VStack(spacing: 20) {
                        statusCard(t, status: status, progress: p, distanceKm: distKm)
                        if #available(iOS 16.2, *) {
                            liveActivityButton(t, status: status, progress: p)
                        }
                        if mapStops.count >= 2 {
                            routeMapCard(mapStops,
                                         trainProgress: Double((p * 200).rounded() / 200),
                                         stopped: status.isStopped)
                        }
                        timeline(stops(for: t), status: status, progress: p)
                    }
                    .padding(18)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash").font(.system(size: 44)).foregroundStyle(Brand.textSoft)
                        Text(L("Aucun voyage en cours")).font(.headline).foregroundStyle(Brand.label)
                        Text(L("Réservez un trajet pour le suivre ici."))
                            .font(.subheadline).foregroundStyle(Brand.textSoft).multilineTextAlignment(.center)
                    }.padding(40)
                }
            }
            .background(Brand.sand.ignoresSafeArea())
            .navigationTitle(L("Suivi en direct"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Show an in-app rationale before the system prompt (only the first time).
            switch loc.status {
            case .notDetermined:                       showLocationPrimer = true
            case .authorizedWhenInUse, .authorizedAlways: loc.startIfAuthorized()
            default:                                   break   // denied/restricted — respect it
            }
            if let t = ticket {
                NotificationService.notifyDisruption(for: t, status: store.liveStatus(for: t))
            }
            if #available(iOS 16.2, *) { liveActivityOn = TripActivityController.shared.isActive }
        }
        .sheet(isPresented: $showLocationPrimer) {
            LocationPrimerView(
                onAllow: { showLocationPrimer = false; loc.request() },
                onSkip:  { showLocationPrimer = false })
                .presentationDetents([.height(400)])
        }
        .onReceive(timer) { t in
            now = t
            guard let tk = ticket else { return }
            let s = store.liveStatus(for: tk)
            let arrival = tk.outbound.arrive.addingTimeInterval(Double(s.delayMinutes) * 60)
            let remMin = arrival.timeIntervalSince(t) / 60

            // "Get ready" alert when the destination is ~5 min away.
            if t >= tk.outbound.depart, remMin > 0, remMin <= 5 {
                NotificationService.notifyArrivalSoon(for: tk)
            }

            // Arrival: the journey is complete, OR the traveller's phone is at the
            // destination station (whichever comes first).
            let atDestination = StationGeo.coordinate(tk.outbound.to.name).flatMap { c in
                loc.location.map { $0.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude)) }
            }.map { $0 < 400 } ?? false
            if t >= arrival || atDestination {
                NotificationService.notifyArrived(for: tk)
            }

            // Hurry up: departure is imminent and the traveller is still far from
            // the boarding station (i.e. not on the train yet).
            let toDep = tk.outbound.depart.timeIntervalSince(t) / 60
            if toDep > 0, toDep <= 15,
               let dep = StationGeo.coordinate(tk.outbound.from.name),
               let here = loc.location,
               here.distance(from: CLLocation(latitude: dep.latitude, longitude: dep.longitude)) > 1200 {
                NotificationService.notifyHurry(for: tk, minutes: Int(ceil(toDep)))
            }

            // Keep the lock-screen Live Activity in sync (and end it on arrival).
            if #available(iOS 16.2, *), TripActivityController.shared.isActive {
                let p = journeyProgress(tk, delay: s.delayMinutes)
                TripActivityController.shared.update(activityState(tk, status: s, progress: p))
                if t >= arrival { TripActivityController.shared.end(); liveActivityOn = false }
            }
        }
        .fullScreenCover(isPresented: $showMap) {
            if let t = ticket {
                let s = stops(for: t).compactMap { st -> RouteMapView.Stop? in
                    guard let c = StationGeo.coordinate(st.name) else { return nil }
                    return RouteMapView.Stop(id: st.name, coord: c)
                }
                let status = store.liveStatus(for: t)
                FullRouteMapView(stops: s, depart: t.outbound.depart, arrive: t.outbound.arrive,
                                 delay: status.delayMinutes, status: status,
                                 route: "\(t.outbound.from.name) → \(t.outbound.to.name)")
            }
        }
    }

    private func statusColor(_ s: TrainStatus) -> Color {
        switch s {
        case .onTime:               return Color(hex: 0x7EF0A8)   // green
        case .delayed, .disrupted:  return Color(hex: 0xFFC15A)   // amber
        case .stopped:              return Color(hex: 0xFF8A7A)   // red
        }
    }

    private func statusText(_ s: TrainStatus) -> String {
        switch s {
        case .onTime:          return L("À l'heure")
        case .delayed(let m):  return "\(L("Retard")) +\(m) min"
        case .disrupted:       return L("Trafic perturbé")
        case .stopped:         return L("Train arrêté")
        }
    }

    // MARK: Live Activity (lock screen / Dynamic Island)

    @available(iOS 16.2, *)
    private func activityState(_ t: Ticket, status: TrainStatus, progress: CGFloat) -> TripActivityAttributes.ContentState {
        let arrival = t.outbound.arrive.addingTimeInterval(Double(status.delayMinutes) * 60)
        let departed = now >= t.outbound.depart
        let arrived = now >= arrival
        let remaining = max(0, Int(arrival.timeIntervalSince(now) / 60))
        let toDep = max(0, Int(t.outbound.depart.timeIntervalSince(now) / 60))
        let headline: String
        if arrived { headline = L("Arrivé à destination") }
        else if departed { headline = String(format: L("%d min avant l'arrivée"), remaining) }
        else { headline = String(format: L("Départ dans %d min"), toDep) }

        // Intermediate cities the train passes through + the next one.
        let all = stops(for: t)
        let next = all.first(where: { progress < $0.position })
        let intermediate = all.dropFirst().dropLast().map { Double($0.position) }

        // Accident / slowdown line.
        let disruption: String
        switch status {
        case .onTime:           disruption = ""
        case .delayed(let m):   disruption = String(format: L("Ralentissement · retard ~%d min"), m)
        case .disrupted(let r): disruption = r
        case .stopped(let r):   disruption = r
        }

        return TripActivityAttributes.ContentState(
            progress: Double((min(progress, 1) * 100).rounded() / 100),
            departDate: t.outbound.depart,
            arriveDate: arrival,
            headline: headline,
            statusText: departed ? statusText(status) : L("À quai"),
            stopped: status.isStopped,
            nextStop: arrived ? "" : (next?.name ?? t.outbound.to.name),
            nextStopTime: next.map { Fmt.time.string(from: $0.time) } ?? "",
            stopFractions: Array(intermediate),
            disruption: disruption)
    }

    @available(iOS 16.2, *)
    private func liveActivityButton(_ t: Ticket, status: TrainStatus, progress: CGFloat) -> some View {
        Button {
            Haptics.tap()
            if TripActivityController.shared.isActive {
                TripActivityController.shared.end(); liveActivityOn = false
            } else {
                TripActivityController.shared.start(
                    reference: t.reference, from: t.outbound.from.name,
                    to: t.outbound.to.name, line: t.outbound.type.rawValue,
                    state: activityState(t, status: status, progress: progress))
                liveActivityOn = true
            }
        } label: {
            Label(liveActivityOn ? L("Arrêter le suivi sur l'écran verrouillé")
                                 : L("Suivre sur l'écran verrouillé"),
                  systemImage: liveActivityOn ? "lock.open.fill" : "lock.iphone")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background((liveActivityOn ? Color.red : Brand.orange).opacity(0.12), in: Capsule())
                .foregroundStyle(liveActivityOn ? Color.red : Brand.orange)
        }
        .accessibilityLabel(Text(liveActivityOn ? L("Arrêter le suivi sur l'écran verrouillé")
                                                : L("Suivre sur l'écran verrouillé")))
    }

    private func statusCard(_ t: Ticket, status: TrainStatus, progress: CGFloat, distanceKm: Double?) -> some View {
        let maxSpeed = t.outbound.type.isHighSpeed ? 320 : 160
        let stopped = status.isStopped
        let arrival = t.outbound.arrive.addingTimeInterval(Double(status.delayMinutes) * 60)
        let departed = now >= t.outbound.depart
        let arrived = now >= arrival
        let cruising = departed && !arrived && !stopped
        let sColor = statusColor(status)
        // Realistic cruising speed: accelerates out of the station, peaks mid-route.
        let speed = cruising ? Int(Double(maxSpeed) * (0.55 + 0.45 * sin(Double(progress) * .pi))) : 0
        let remaining = max(0, Int(arrival.timeIntervalSince(now) / 60))
        let toDeparture = max(0, Int(t.outbound.depart.timeIntervalSince(now) / 60))
        let topLabel = arrived ? L("ARRIVÉ") : (departed ? (stopped ? L("ARRÊTÉ") : L("EN VOYAGE")) : L("À QUAI"))
        let topIcon = arrived ? "checkmark.circle.fill" : (departed ? (stopped ? "pause.circle.fill" : "dot.radiowaves.left.and.right") : "clock.fill")
        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Brand.inkGrad)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RadialGradient(colors: [sColor.opacity(0.35), .clear],
                                     center: .topTrailing, startRadius: 0, endRadius: 220))
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(topLabel, systemImage: topIcon)
                        .font(.caption.weight(.bold)).foregroundStyle(sColor)
                    Spacer()
                    TypePill(type: t.outbound.type)
                }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        Text(t.reference).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(.white)
                        Text("\(t.outbound.from.name) → \(t.outbound.to.name)").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(speed) km/h")
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                            .foregroundStyle(stopped ? sColor : Brand.orange2)
                        Text(L("vitesse")).font(.caption2).foregroundStyle(.white.opacity(0.6))
                    }
                }
                InDriveTrack(progress: min(progress, 1), stopped: stopped,
                             fromLabel: t.outbound.from.name, toLabel: t.outbound.to.name)
                HStack {
                    Label(departed ? statusText(status) : "\(L("Départ")) \(Fmt.time.string(from: t.outbound.depart))",
                          systemImage: departed ? status.icon : "clock")
                        .font(.caption.weight(.semibold)).foregroundStyle(sColor)
                    Spacer()
                    Text(arrived
                         ? L("Arrivé")
                         : (departed
                            ? "\(L("Arrivée")) \(Fmt.time.string(from: arrival)) · \(remaining / 60)h\(String(format: "%02d", remaining % 60))"
                            : "\(L("Départ dans")) \(toDeparture / 60)h\(String(format: "%02d", toDeparture % 60))"))
                        .font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                if let km = distanceKm {
                    let d = km < 1 ? String(format: "%.0f m", km * 1000) : String(format: "%.0f km", km)
                    Label(String(format: L("À %@ de votre train"), d), systemImage: "location.fill")
                        .font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
                if let detail = status.detail {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill").font(.caption2).foregroundStyle(sColor)
                        Text(detail).font(.caption2).foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(sColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(18)
        }
        .accessibilityElement(children: .combine)
    }

    private func routeMapCard(_ stops: [RouteMapView.Stop], trainProgress: Double, stopped: Bool) -> some View {
        Button { showMap = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill").font(.caption).foregroundStyle(Brand.orange)
                    Text(L("Itinéraire")).font(.caption.weight(.bold)).tracking(1).foregroundStyle(Brand.textSoft)
                    Spacer()
                    Label(L("Agrandir"), systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Brand.orange)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                RouteMapView(stops: stops, trainProgress: trainProgress, stopped: stopped)
                    .frame(height: 200)
                    .allowsHitTesting(false)
            }
            .background(Brand.cream)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.black.opacity(0.06)))
            .shadow(color: Brand.ink.opacity(0.08), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L("Itinéraire")))
        .accessibilityHint(Text(L("Agrandir")))
    }

    private func timeline(_ stops: [Stop], status: TrainStatus, progress: CGFloat) -> some View {
        let stopped = status.isStopped
        let marker = stopped ? statusColor(status) : Brand.orange
        let next = nextStopIndex(stops, progress: progress)
        return Card {
            HStack(alignment: .top, spacing: 0) {
                GeometryReader { geo in
                    let h = geo.size.height
                    ZStack(alignment: .top) {
                        Capsule().fill(Color.black.opacity(0.1)).frame(width: 4)
                        Capsule().fill(Brand.warm).frame(width: 4, height: min(progress, 1) * h)
                        ForEach(stops) { s in
                            Circle()
                                .fill(progress >= s.position ? Brand.orange : Color.white)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().strokeBorder(Brand.orange, lineWidth: 2.5))
                                .position(x: 2, y: s.position * h)
                        }
                        Image(systemName: stopped ? "pause.fill" : "tram.fill")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 30, height: 30).background(marker, in: Circle())
                            .shadow(color: marker.opacity(0.6), radius: 6)
                            .position(x: 2, y: min(progress, 1) * h)
                    }
                    .frame(width: 4)
                }
                .frame(width: 22)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.element.id) { idx, s in
                        let passed = progress >= s.position
                        let isNext = (next == idx)
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(s.name)
                                        .font(.system(.subheadline, design: .rounded).weight(isNext ? .bold : .semibold))
                                        .foregroundStyle(passed ? Brand.label : (isNext ? Brand.orange : Brand.textSoft))
                                    if isNext {
                                        Text(L("Prochain arrêt"))
                                            .font(.system(size: 8, weight: .bold)).tracking(0.5).foregroundStyle(.white)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Brand.orange, in: Capsule())
                                    }
                                }
                                HStack(spacing: 10) {
                                    Text(Fmt.time.string(from: s.time)).font(.caption2).foregroundStyle(Brand.textSoft)
                                    Text("\(L("Voie")) \(s.voie)").font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(isNext ? Brand.orange : Brand.textSoft)
                                    if s.dwell > 0 {
                                        Label(String(format: L("Arrêt %d min"), s.dwell), systemImage: "pause.circle")
                                            .font(.system(size: 10)).foregroundStyle(Brand.textSoft)
                                    }
                                }
                            }
                            Spacer()
                            if passed {
                                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Brand.orange)
                            }
                        }
                        .frame(height: idx == stops.count - 1 ? 44 : 72, alignment: .top)
                    }
                }
            }
            .frame(minHeight: 250)
        }
    }
}

/// A map point: either a station or the moving train.
struct RouteMapPoint: Identifiable {
    let id: String
    let coord: CLLocationCoordinate2D
    let isTrain: Bool
}

/// Marker drawn for each annotation.
struct RouteAnnotationView: View {
    let point: RouteMapPoint
    var stopped: Bool = false

    var body: some View {
        if point.isTrain {
            Image(systemName: stopped ? "pause.fill" : "tram.fill")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(stopped ? Color(hex: 0xFF6F61) : Brand.orange, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: Brand.orange.opacity(0.6), radius: 6)
        } else {
            VStack(spacing: 2) {
                Circle().fill(.white).frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(Brand.orange, lineWidth: 3))
                Text(point.id)
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(Brand.label)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

/// Inline route map with the live (interpolated) train position. iOS 16 compatible.
struct RouteMapView: View {
    struct Stop: Identifiable, Equatable {
        let id: String
        let coord: CLLocationCoordinate2D
        static func == (l: Stop, r: Stop) -> Bool {
            l.id == r.id && l.coord.latitude == r.coord.latitude && l.coord.longitude == r.coord.longitude
        }
    }

    let stops: [Stop]
    var trainProgress: Double = 0
    var stopped: Bool = false

    /// Position of the train interpolated along the straight segments between stops.
    static func interpolate(_ stops: [Stop], _ p: Double) -> CLLocationCoordinate2D? {
        guard let first = stops.first else { return nil }
        guard stops.count >= 2 else { return first.coord }
        let clamped = min(max(p, 0), 1)
        let x = clamped * Double(stops.count - 1)
        let k = min(Int(x), stops.count - 2)
        let t = x - Double(k)
        let a = stops[k].coord, b = stops[k + 1].coord
        return CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                      longitude: a.longitude + (b.longitude - a.longitude) * t)
    }

    static func framingRegion(_ stops: [Stop]) -> MKCoordinateRegion {
        let coords = stops.map(\.coord)
        guard let first = coords.first else {
            return MKCoordinateRegion(center: .init(latitude: 33.9, longitude: -6.8),
                                      span: .init(latitudeDelta: 4, longitudeDelta: 4))
        }
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        let minLat = lats.min() ?? first.latitude, maxLat = lats.max() ?? first.latitude
        let minLon = lons.min() ?? first.longitude, maxLon = lons.max() ?? first.longitude
        return MKCoordinateRegion(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: .init(latitudeDelta: max(0.4, (maxLat - minLat) * 1.6),
                        longitudeDelta: max(0.4, (maxLon - minLon) * 1.6)))
    }

    static func annotations(_ stops: [Stop], _ progress: Double) -> [RouteMapPoint] {
        var pts = stops.map { RouteMapPoint(id: $0.id, coord: $0.coord, isTrain: false) }
        if let c = interpolate(stops, progress) {
            pts.append(RouteMapPoint(id: "__train", coord: c, isTrain: true))
        }
        return pts
    }

    var body: some View {
        Map(coordinateRegion: .constant(Self.framingRegion(stops)),
            interactionModes: [],
            showsUserLocation: true,
            annotationItems: Self.annotations(stops, trainProgress)) { p in
            MapAnnotation(coordinate: p.coord) { RouteAnnotationView(point: p, stopped: stopped) }
        }
    }
}

/// Full-screen, interactive map that follows the train live (clock-based).
struct FullRouteMapView: View {
    let stops: [RouteMapView.Stop]
    var depart: Date
    var arrive: Date
    var delay: Int
    var status: TrainStatus
    var route: String

    @Environment(\.dismiss) private var dismiss
    @State private var recenterTrigger = 0
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var stopped: Bool { status.isStopped }

    private var progress: CGFloat {
        let total = arrive.addingTimeInterval(Double(delay) * 60).timeIntervalSince(depart)
        guard total > 0 else { return 0 }
        return CGFloat(min(max(now.timeIntervalSince(depart) / total, 0), 1))
    }

    private var statusLine: String {
        switch status {
        case .onTime:          return L("À l'heure")
        case .delayed(let m):  return "\(L("Retard")) +\(m) min"
        case .disrupted:       return L("Trafic perturbé")
        case .stopped:         return L("Train arrêté")
        }
    }
    private var statusColor: Color {
        switch status {
        case .onTime:               return Color(hex: 0x16A34A)
        case .delayed, .disrupted:  return Color(hex: 0xE0900A)
        case .stopped:              return Color(hex: 0xE0480A)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            RailMapView(stops: stops,
                        trainProgress: Double((progress * 200).rounded() / 200),
                        stopped: stopped,
                        interactive: true,
                        recenter: recenterTrigger)
                .ignoresSafeArea()

            header

            VStack {
                Spacer()
                Button { recenterTrigger += 1; Haptics.tap() } label: {
                    Label(L("Centrer sur le train"), systemImage: "scope")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.vertical, 12).padding(.horizontal, 18)
                        .background(Brand.orange, in: Capsule())
                        .shadow(color: Brand.orange.opacity(0.5), radius: 10, y: 4)
                }
                .padding(.bottom, 34)
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(route).font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(Brand.label)
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                    Text(statusLine).font(.caption.weight(.semibold)).foregroundStyle(statusColor)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.subheadline.weight(.bold)).foregroundStyle(Brand.label)
                    .frame(width: 34, height: 34).background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 14).padding(.top, 6)
    }
}

/// In-app rationale shown before the system location prompt, so the user
/// understands why it's needed (improves the allow-rate and avoids a cold ask).
struct LocationPrimerView: View {
    var onAllow: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Brand.orange.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: "location.fill")
                    .font(.system(size: 40, weight: .bold)).foregroundStyle(Brand.warm)
            }
            .padding(.top, 26)
            .accessibilityHidden(true)

            Text(L("Suivez votre train en direct"))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.label).multilineTextAlignment(.center)
            Text(L("Votre position vous situe sur la carte et calcule votre distance jusqu'au train et aux gares. Utilisée uniquement lorsque l'app est ouverte."))
                .font(.subheadline).foregroundStyle(Brand.textSoft)
                .multilineTextAlignment(.center).padding(.horizontal, 26)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Button(action: onAllow) {
                    Text(L("Autoriser la localisation")).frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: onSkip) {
                    Text(L("Plus tard")).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.textSoft)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .background(Brand.sand.ignoresSafeArea())
    }
}

/// Horizontal ride-tracking-style bar: origin dot → moving train → destination
/// ring on a dashed line. ONCF-branded; mirrors the familiar ride-hailing layout.
struct InDriveTrack: View {
    var progress: CGFloat
    var stopped: Bool
    var fromLabel: String
    var toLabel: String

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                let w = geo.size.width
                let inset: CGFloat = 13
                let y: CGFloat = 13
                let x = inset + max(0, w - inset * 2) * min(max(progress, 0), 1)
                ZStack(alignment: .topLeading) {
                    // Full dashed track.
                    Path { p in
                        p.move(to: CGPoint(x: inset, y: y)); p.addLine(to: CGPoint(x: w - inset, y: y))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 8]))
                    .foregroundColor(.white.opacity(0.28))
                    // Travelled portion.
                    Path { p in
                        p.move(to: CGPoint(x: inset, y: y)); p.addLine(to: CGPoint(x: x, y: y))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundColor(stopped ? Color(hex: 0xFF6F61) : Brand.orange)
                    // Origin dot.
                    Circle().fill(.white).frame(width: 11, height: 11).position(x: inset, y: y)
                    // Destination ring.
                    Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2.5)
                        .frame(width: 11, height: 11).position(x: w - inset, y: y)
                    // Moving train marker.
                    Image(systemName: stopped ? "pause.fill" : "tram.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(stopped ? Color(hex: 0xFF6F61) : Brand.orange, in: Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .shadow(color: Brand.orange.opacity(0.6), radius: 5)
                        .position(x: x, y: y)
                }
            }
            .frame(height: 26)
            .animation(.easeInOut(duration: 0.6), value: progress)

            HStack {
                Text(fromLabel).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(toLabel).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(fromLabel) → \(toLabel), \(Int(progress * 100)) %"))
    }
}

#Preview { TrackView().environmentObject(AppStore()) }
