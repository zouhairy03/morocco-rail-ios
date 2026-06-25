//
//  Components.swift
//  Reusable UI pieces: QR code, boarding pass, route header.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - QR code

struct QRCodeView: View {
    let string: String
    var size: CGFloat = 120
    var body: some View {
        if let img = Self.generate(string) {
            Image(uiImage: img)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
                .accessibilityLabel(Text("Code QR d'embarquement"))
        } else {
            RoundedRectangle(cornerRadius: 8).fill(Brand.ink.opacity(0.1))
                .frame(width: size, height: size)
        }
    }

    static func generate(_ string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let out = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 9, y: 9)),
              let cg = context.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Train type pill

struct TypePill: View {
    let type: TrainType
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: type.icon).font(.caption2.weight(.bold))
            Text(type.rawValue).font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(type.isHighSpeed ? AnyShapeStyle(Brand.warm) : AnyShapeStyle(Brand.ink),
                    in: Capsule())
    }
}

// MARK: - Route header (times + cities + connector)

struct RouteHeader: View {
    let journey: Journey
    var compact = false
    var body: some View {
        HStack(alignment: .top) {
            stop(time: Fmt.time.string(from: journey.depart), city: journey.from.name, align: .leading)
            Spacer(minLength: 8)
            VStack(spacing: 4) {
                Text(journey.durationText)
                    .font(.caption2.weight(.semibold)).foregroundStyle(Brand.clay)
                ZStack {
                    Capsule().fill(Color.black.opacity(0.12)).frame(height: 2)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Brand.orange)
                        .padding(.horizontal, 6)
                        .background(Brand.cream)
                }
                .accessibilityHidden(true)
                Text("direct").font(.system(size: 9)).foregroundStyle(Brand.textSoft)
            }
            .frame(maxWidth: 110)
            .padding(.top, compact ? 4 : 10)
            Spacer(minLength: 8)
            stop(time: Fmt.time.string(from: journey.arrive), city: journey.to.name, align: .trailing)
        }
    }

    private func stop(time: String, city: String, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 2) {
            Text(time)
                .font(.system(size: compact ? 24 : 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Brand.label)
            Text(city.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Brand.textSoft)
        }
    }
}

// MARK: - Boarding pass card

struct BoardingPass: View {
    let ticket: Ticket
    var body: some View {
        VStack(spacing: 0) {
            // header
            HStack {
                LogoMark(size: 30)
                Text("ONCF ").font(.system(.headline, design: .rounded).weight(.bold)).foregroundColor(.white)
                + Text("voyages").font(.system(.headline, design: .rounded)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(ticket.isRoundTrip ? "ALLER-RETOUR" : "ALLER SIMPLE")
                    .font(.system(size: 9, weight: .bold)).tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
            .background(Brand.inkGrad)

            VStack(spacing: 16) {
                HStack {
                    TypePill(type: ticket.outbound.type)
                    Spacer()
                    Text(Fmt.dayLong.string(from: ticket.outbound.depart))
                        .font(.caption).foregroundStyle(Brand.textSoft)
                }
                if ticket.isRoundTrip { legBadge("ALLER", "arrow.right") }
                RouteHeader(journey: ticket.outbound)

                if let rt = ticket.returnTrip {
                    Divider()
                    HStack {
                        legBadge("RETOUR", "arrow.left")
                        Spacer()
                        Text(Fmt.dayLong.string(from: rt.depart))
                            .font(.caption).foregroundStyle(Brand.textSoft)
                    }
                    RouteHeader(journey: rt)
                }

                HStack(spacing: 0) {
                    info("VOITURE", "\(ticket.coach)")
                    Divider().frame(height: 28)
                    info("PLACE", ticket.seat)
                    Divider().frame(height: 28)
                    info("CLASSE", ticket.fareClass == .first ? "1ʳᵉ" : "2ᵉ")
                    Divider().frame(height: 28)
                    info("VOYAGEURS", "\(ticket.passengers)")
                }
            }
            .padding(16)
            .background(Brand.cream)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.black.opacity(0.06)))
        .shadow(color: Brand.ink.opacity(0.12), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
    }

    private func legBadge(_ key: String, _ icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(L(key)).font(.system(size: 9, weight: .bold)).tracking(1.5)
        }
        .foregroundStyle(Brand.clay)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func info(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 8.5, weight: .semibold)).foregroundStyle(Brand.textSoft)
            Text(value).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(Brand.label)
        }
        .frame(maxWidth: .infinity)
    }
}
