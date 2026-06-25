//
//  TicketPDF.swift
//  Renders a printable / shareable PDF e-ticket (billet) for a Ticket.
//

import UIKit

enum TicketPDF {
    static func generate(_ ticket: Ticket) -> URL? {
        let pageW: CGFloat = 595, pageH: CGFloat = 842      // A4 at 72 dpi
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("billet-\(ticket.reference).pdf")

        let orange = UIColor(rgb: 0xF2660A)
        let ink = UIColor(rgb: 0x0B1020)
        let soft = UIColor(rgb: 0x5A6178)

        func str(_ s: String, _ size: CGFloat, _ color: UIColor, weight: UIFont.Weight = .regular) -> NSAttributedString {
            NSAttributedString(string: s, attributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
        }

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                let cg = ctx.cgContext

                // Header band
                orange.setFill()
                cg.fill(CGRect(x: 0, y: 0, width: pageW, height: 90))
                str("ONCF Voyages", 24, .white, weight: .heavy).draw(at: CGPoint(x: margin, y: 26))
                str("E-BILLET", 12, UIColor.white.withAlphaComponent(0.9), weight: .bold)
                    .draw(at: CGPoint(x: pageW - margin - 70, y: 36))

                var y: CGFloat = 120

                // Reference + trip kind
                str("RÉFÉRENCE", 9, soft, weight: .semibold).draw(at: CGPoint(x: margin, y: y))
                str(ticket.reference, 22, ink, weight: .bold).draw(at: CGPoint(x: margin, y: y + 12))
                str(ticket.isRoundTrip ? "ALLER-RETOUR" : "ALLER SIMPLE", 11, orange, weight: .bold)
                    .draw(at: CGPoint(x: pageW - margin - 110, y: y + 18))
                y += 60

                // Legs
                func leg(_ tag: String, _ j: Journey) {
                    str(tag, 10, orange, weight: .bold).draw(at: CGPoint(x: margin, y: y))
                    y += 16
                    let timeFrom = Fmt.time.string(from: j.depart)
                    let timeTo = Fmt.time.string(from: j.arrive)
                    str("\(timeFrom)  \(j.from.name.uppercased())", 15, ink, weight: .bold)
                        .draw(at: CGPoint(x: margin, y: y))
                    str("→", 15, soft).draw(at: CGPoint(x: pageW / 2 - 8, y: y))
                    let dest = str("\(timeTo)  \(j.to.name.uppercased())", 15, ink, weight: .bold)
                    dest.draw(at: CGPoint(x: pageW - margin - dest.size().width, y: y))
                    y += 22
                    str("\(j.type.rawValue) · \(Fmt.dayLong.string(from: j.depart)) · \(j.durationText)", 11, soft)
                        .draw(at: CGPoint(x: margin, y: y))
                    y += 30
                }
                leg("ALLER →", ticket.outbound)
                if let rt = ticket.returnTrip { leg("← RETOUR", rt) }

                // Separator
                soft.withAlphaComponent(0.3).setStroke()
                cg.move(to: CGPoint(x: margin, y: y)); cg.addLine(to: CGPoint(x: pageW - margin, y: y)); cg.strokePath()
                y += 20

                // Info grid
                let cols: [(String, String)] = [
                    ("VOITURE", "\(ticket.coach)"),
                    ("CLASSE", ticket.fareClass == .first ? "1ʳᵉ Prestige" : "2ᵉ Confort"),
                    ("VOYAGEURS", "\(ticket.passengers)"),
                    ("TOTAL", Fmt.price(ticket.total))
                ]
                let colW = (pageW - margin * 2) / CGFloat(cols.count)
                for (i, c) in cols.enumerated() {
                    let x = margin + colW * CGFloat(i)
                    str(c.0, 8.5, soft, weight: .semibold).draw(at: CGPoint(x: x, y: y))
                    str(c.1, 14, ink, weight: .bold).draw(at: CGPoint(x: x, y: y + 12))
                }
                y += 50

                // Travelers
                str("VOYAGEURS", 9, soft, weight: .semibold).draw(at: CGPoint(x: margin, y: y)); y += 16
                for p in ticket.travelers {
                    str("• \(p.name) — \(p.type.rawValue) · Voit. \(ticket.coach) place \(p.seat)", 12, ink)
                        .draw(at: CGPoint(x: margin, y: y))
                    y += 18
                }
                y += 16

                // QR code
                if let qr = QRCodeView.generate("ONCF|\(ticket.reference)|\(ticket.passengerName)") {
                    let size: CGFloat = 150
                    qr.draw(in: CGRect(x: (pageW - size) / 2, y: y, width: size, height: size))
                    y += size + 6
                    let ref = str(ticket.reference, 12, ink, weight: .bold)
                    ref.draw(at: CGPoint(x: (pageW - ref.size().width) / 2, y: y))
                    y += 30
                }

                // Caution box
                let cautionRect = CGRect(x: margin, y: pageH - 120, width: pageW - margin * 2, height: 70)
                UIColor(rgb: 0xFFF4EA).setFill()
                UIBezierPath(roundedRect: cautionRect, cornerRadius: 10).fill()
                str("⚠︎ À SAVOIR", 10, orange, weight: .bold)
                    .draw(at: CGPoint(x: margin + 12, y: pageH - 110))
                let caution = "Présentez-vous 20 min avant le départ, muni d'une pièce d'identité valide. "
                    + "Billet nominatif et non cessible · échange & annulation gratuits jusqu'à 1h avant le départ."
                str(caution, 9, soft).draw(in: CGRect(x: margin + 12, y: pageH - 94, width: pageW - margin * 2 - 24, height: 44))
            }
            return url
        } catch {
            return nil
        }
    }
}
