//
//  ONCFWidgetsLiveActivity.swift
//  ONCFWidgets — lock-screen + Dynamic Island live trip tracker.
//
//  `TripActivityAttributes` is declared identically in the main app
//  (TripActivity.swift); ActivityKit pairs them by name + content shape.
//  The route bar is driven by `ProgressView(timerInterval:)`, so the train
//  advances on the lock screen by itself — no running app required.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TripActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var departDate: Date
        var arriveDate: Date
        var headline: String
        var statusText: String
        var stopped: Bool
        var nextStop: String
        var nextStopTime: String
        var stopFractions: [Double]
        var disruption: String
    }
    var reference: String
    var from: String
    var to: String
    var line: String
}

// ONCF brand colours (self-contained — the extension can't see the app's Theme).
private let oncfOrange = Color(red: 0.949, green: 0.40, blue: 0.039)
private let oncfRed    = Color(red: 1.0,   green: 0.435, blue: 0.380)
private let oncfInk    = Color(red: 0.043, green: 0.063, blue: 0.125)

/// Dashed origin → train → destination track. Reads `fractionCompleted` from a
/// timer-based ProgressView, so it self-advances on the Lock Screen. Intermediate
/// stations are drawn as ticks.
private struct TrackStyle: ProgressViewStyle {
    var stopped: Bool
    var stops: [Double]
    func makeBody(configuration: Configuration) -> some View {
        let f = CGFloat(configuration.fractionCompleted ?? 0)
        return GeometryReader { geo in
            let w = geo.size.width
            let inset: CGFloat = 11
            let span = max(0, w - inset * 2)
            let y: CGFloat = 11
            let x = inset + span * min(max(f, 0), 1)
            ZStack(alignment: .topLeading) {
                Path { p in p.move(to: CGPoint(x: inset, y: y)); p.addLine(to: CGPoint(x: w - inset, y: y)) }
                    .stroke(style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [1, 7]))
                    .foregroundColor(.white.opacity(0.28))
                Path { p in p.move(to: CGPoint(x: inset, y: y)); p.addLine(to: CGPoint(x: x, y: y)) }
                    .stroke(style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .foregroundColor(stopped ? oncfRed : oncfOrange)
                // Intermediate station ticks.
                ForEach(stops.indices, id: \.self) { i in
                    let sx = inset + span * CGFloat(min(max(stops[i], 0), 1))
                    Circle().fill(f >= CGFloat(stops[i]) ? oncfOrange : Color.white.opacity(0.55))
                        .frame(width: 5, height: 5).position(x: sx, y: y)
                }
                Circle().fill(.white).frame(width: 9, height: 9).position(x: inset, y: y)
                Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2)
                    .frame(width: 9, height: 9).position(x: w - inset, y: y)
                Image(systemName: stopped ? "pause.fill" : "tram.fill")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(stopped ? oncfRed : oncfOrange, in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    .position(x: x, y: y)
            }
        }
        .frame(height: 22)
    }
}

/// Self-advancing track bar (origin → train → destination).
private func routeBar(_ s: TripActivityAttributes.ContentState) -> some View {
    ProgressView(timerInterval: s.departDate...max(s.departDate.addingTimeInterval(60), s.arriveDate),
                 countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
        .progressViewStyle(TrackStyle(stopped: s.stopped, stops: s.stopFractions))
}

struct ONCFWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            let s = context.state
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label(context.attributes.line, systemImage: "bolt.fill")
                        .font(.caption2.weight(.bold)).foregroundColor(oncfOrange)
                    Spacer()
                    Text(context.attributes.reference)
                        .font(.caption2.weight(.semibold)).foregroundColor(.white.opacity(0.6))
                }
                // Headline + live ETA that ticks on the lock screen.
                HStack(alignment: .firstTextBaseline) {
                    Text(s.headline)
                        .font(.system(.headline, design: .rounded).weight(.bold)).foregroundColor(.white)
                    Spacer()
                    if s.arriveDate > Date() && s.departDate <= Date() {
                        Text(s.arriveDate, style: .timer)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .monospacedDigit().multilineTextAlignment(.trailing)
                            .foregroundColor(oncfOrange).frame(maxWidth: 70)
                    }
                }
                routeBar(s)
                HStack {
                    Text(context.attributes.from).font(.caption2).foregroundColor(.white.opacity(0.7))
                    Spacer()
                    if !s.nextStop.isEmpty {
                        (Text("→ ").foregroundColor(oncfOrange)
                         + Text(s.nextStop).foregroundColor(.white)
                         + Text(s.nextStopTime.isEmpty ? "" : " · \(s.nextStopTime)").foregroundColor(.white.opacity(0.6)))
                            .font(.caption2.weight(.semibold)).lineLimit(1)
                    }
                    Spacer()
                    Text(context.attributes.to).font(.caption2).foregroundColor(.white.opacity(0.7))
                }
                if !s.disruption.isEmpty {
                    Label(s.disruption, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.medium)).foregroundColor(oncfRed)
                        .lineLimit(2)
                }
            }
            .padding(15)
            .activityBackgroundTint(oncfInk)
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.from, systemImage: "tram.fill")
                        .font(.caption2.weight(.semibold)).foregroundColor(oncfOrange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.to)
                        .font(.caption2.weight(.semibold)).foregroundColor(.white.opacity(0.8))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(s.disruption.isEmpty ? s.headline : s.disruption)
                        .font(.caption.weight(.bold))
                        .foregroundColor(s.disruption.isEmpty ? .white : oncfRed).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) { routeBar(s) }
            } compactLeading: {
                Image(systemName: s.stopped ? "pause.fill" : "tram.fill").foregroundColor(oncfOrange)
            } compactTrailing: {
                if s.arriveDate > Date() && s.departDate <= Date() {
                    Text(s.arriveDate, style: .timer).monospacedDigit()
                        .font(.caption2.weight(.bold)).foregroundColor(oncfOrange).frame(maxWidth: 44)
                } else {
                    Image(systemName: "clock").foregroundColor(oncfOrange)
                }
            } minimal: {
                Image(systemName: "tram.fill").foregroundColor(oncfOrange)
            }
            .keylineTint(oncfOrange)
        }
    }
}
