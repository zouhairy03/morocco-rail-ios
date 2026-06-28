//
//  WalletPass.swift
//  "Add to Apple Wallet" for tickets.
//
//  Apple Wallet passes MUST be cryptographically signed with a Pass Type ID
//  certificate. The cert's private key can't live in the app, so signing happens
//  on a small server: the app POSTs the ticket payload below, the server signs a
//  .pkpass and returns the bytes, and the app presents it. Fill PassConfig once
//  you have a Pass Type ID (Apple Developer) + a signing endpoint.
//

import Foundation
import PassKit
import UIKit

enum PassConfig {
    /// 🔧 e.g. "pass.com.oncf.voyages" (created in the Apple Developer portal).
    static let passTypeID = "YOUR_PASS_TYPE_ID"
    static let teamID = "C4RV38LXMF"
    /// 🔧 A URL that signs the payload with your Pass Type ID cert and returns
    /// the .pkpass bytes (PassKit / passkit-generator on a tiny server).
    static let signingEndpoint = "YOUR_PASS_SIGNING_URL"

    static var isConfigured: Bool {
        !passTypeID.hasPrefix("YOUR_") && !signingEndpoint.hasPrefix("YOUR_")
    }
}

enum WalletError: LocalizedError {
    case needsSetup, badPass, network(String)
    var errorDescription: String? {
        switch self {
        case .needsSetup:
            return L("Apple Wallet nécessite un certificat Pass Type ID et un service de signature côté serveur.")
        case .badPass:   return L("Le pass reçu est invalide.")
        case .network(let m): return String(format: L("Connexion au service impossible : %@"), m)
        }
    }
}

enum WalletService {
    /// The pass.json payload sent to the signing server. Ready now, even before
    /// the certificate exists — only the signature step is server-side.
    static func passPayload(for ticket: Ticket) -> [String: Any] {
        [
            "formatVersion": 1,
            "passTypeIdentifier": PassConfig.passTypeID,
            "teamIdentifier": PassConfig.teamID,
            "serialNumber": ticket.reference,
            "organizationName": "ONCF Voyages",
            "description": "Billet de train",
            "foregroundColor": "rgb(255,255,255)",
            "backgroundColor": "rgb(11,16,32)",
            "labelColor": "rgb(242,102,10)",
            "boardingPass": [
                "transitType": "PKTransitTypeTrain",
                "primaryFields": [
                    ["key": "from", "label": "DÉPART", "value": ticket.outbound.from.name],
                    ["key": "to", "label": "ARRIVÉE", "value": ticket.outbound.to.name]
                ],
                "secondaryFields": [
                    ["key": "depart", "label": "HEURE", "value": Fmt.time.string(from: ticket.outbound.depart)],
                    ["key": "coach", "label": "VOITURE", "value": "\(ticket.coach)"],
                    ["key": "seat", "label": "PLACE", "value": ticket.seat]
                ],
                "auxiliaryFields": [
                    ["key": "passenger", "label": "VOYAGEUR", "value": ticket.passengerName],
                    ["key": "class", "label": "CLASSE", "value": ticket.fareClass == .first ? "1ʳᵉ" : "2ᵉ"]
                ]
            ],
            "barcode": [
                "format": "PKBarcodeFormatQR",
                "message": "ONCF|\(ticket.reference)|\(ticket.passengerName)",
                "messageEncoding": "iso-8859-1"
            ]
        ]
    }

    /// Fetch the signed pass from the server and present the Wallet sheet.
    @MainActor
    static func add(_ ticket: Ticket) async throws {
        guard PassConfig.isConfigured, let url = URL(string: PassConfig.signingEndpoint) else {
            throw WalletError.needsSetup
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: passPayload(for: ticket))
        let data: Data
        do { (data, _) = try await URLSession.shared.data(for: req) }
        catch { throw WalletError.network(error.localizedDescription) }
        guard let pass = try? PKPass(data: data),
              let vc = PKAddPassesViewController(pass: pass) else { throw WalletError.badPass }
        topViewController()?.present(vc, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
