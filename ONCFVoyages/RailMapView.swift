//
//  RailMapView.swift
//  MapKit map that draws the full route the train follows (polyline), the
//  station markers, the live moving train, and the phone's location.
//

import SwiftUI
import MapKit

final class TrainAnnotation: MKPointAnnotation {}
final class StationAnnotation: MKPointAnnotation {}

struct RailMapView: UIViewRepresentable {
    let stops: [RouteMapView.Stop]
    var trainProgress: Double
    var stopped: Bool
    var interactive: Bool = false
    /// Increment to recenter the map on the train.
    var recenter: Int = 0

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.isScrollEnabled = interactive
        map.isZoomEnabled = interactive
        map.pointOfInterestFilter = .excludingAll
        map.setRegion(RouteMapView.framingRegion(stops), animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.stopped = stopped
        if !c.didSetup {
            let coords = stops.map(\.coord)
            if coords.count >= 2 {
                map.addOverlay(MKPolyline(coordinates: coords, count: coords.count))
            }
            for s in stops {
                let a = StationAnnotation(); a.coordinate = s.coord; a.title = s.id
                map.addAnnotation(a)
            }
            if let tc = RouteMapView.interpolate(stops, trainProgress) {
                c.train.coordinate = tc
                map.addAnnotation(c.train)
            }
            c.didSetup = true
        } else if let tc = RouteMapView.interpolate(stops, trainProgress) {
            c.train.coordinate = tc   // animates smoothly
            if let v = map.view(for: c.train) as? MKMarkerAnnotationView {
                v.markerTintColor = stopped ? UIColor(rgb: 0xFF6F61) : UIColor(rgb: 0xF2660A)
                v.glyphImage = UIImage(systemName: stopped ? "pause.fill" : "tram.fill")
            }
        }
        if interactive, c.lastRecenter != recenter {
            c.lastRecenter = recenter
            if let tc = RouteMapView.interpolate(stops, trainProgress) {
                map.setRegion(MKCoordinateRegion(center: tc,
                              span: .init(latitudeDelta: 1.1, longitudeDelta: 1.1)), animated: true)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let train = TrainAnnotation()
        var didSetup = false
        var stopped = false
        var lastRecenter = 0

        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let r = MKPolylineRenderer(overlay: overlay)
            r.strokeColor = UIColor(rgb: 0xF2660A).withAlphaComponent(0.9)
            r.lineWidth = 5; r.lineCap = .round; r.lineJoin = .round
            return r
        }

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if annotation is TrainAnnotation {
                let id = "train"
                let v = (map.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                v.annotation = annotation
                v.markerTintColor = stopped ? UIColor(rgb: 0xFF6F61) : UIColor(rgb: 0xF2660A)
                v.glyphImage = UIImage(systemName: stopped ? "pause.fill" : "tram.fill")
                v.displayPriority = .required
                v.zPriority = .max
                v.animatesWhenAdded = true
                return v
            }

            let id = "station"
            let v = (map.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            v.annotation = annotation
            v.markerTintColor = UIColor(rgb: 0x0B1020)
            v.glyphImage = UIImage(systemName: "circle.fill")
            v.titleVisibility = .adaptive
            v.displayPriority = .required
            return v
        }
    }
}
