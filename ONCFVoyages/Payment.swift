//
//  Payment.swift
//  Payment processing abstraction + invoice/receipt model.
//
//  `PaymentService` is a protocol; `SandboxPaymentProcessor` mimics a real
//  gateway (CMI / Stripe / Apple Pay) including success & decline scenarios via
//  well-known test cards. Swap it for a live processor + merchant backend
//  without touching the UI — the protocol stays the same.
//

import Foundation

enum PaymentMethod: String, Codable {
    case applePay = "Apple Pay"
    case card = "Carte bancaire"
}

enum PaymentError: LocalizedError {
    case declined, cancelled, insufficientFunds, expiredCard, threeDSecureFailed, network
    var errorDescription: String? {
        switch self {
        case .declined:          return "Paiement refusé par la banque."
        case .cancelled:         return "Paiement annulé."
        case .insufficientFunds: return "Fonds insuffisants sur la carte."
        case .expiredCard:       return "Carte expirée."
        case .threeDSecureFailed:return "Échec de l'authentification 3-D Secure."
        case .network:           return "Connexion au service de paiement impossible."
        }
    }
}

// MARK: - Card brand

enum CardBrand: String, Codable {
    case visa, mastercard, amex, unknown

    /// Detect the network from the card number prefix (BIN ranges).
    static func detect(_ pan: String) -> CardBrand {
        let d = pan.filter(\.isNumber)
        guard let first = d.first else { return .unknown }
        let p2 = Int(d.prefix(2)) ?? 0
        switch first {
        case "4": return .visa
        case "3" where p2 == 34 || p2 == 37: return .amex
        case "5" where (51...55).contains(p2): return .mastercard
        case "2" where (22...27).contains(p2): return .mastercard
        default: return .unknown
        }
    }

    var name: String {
        switch self {
        case .visa: return "VISA"
        case .mastercard: return "Mastercard"
        case .amex: return "Amex"
        case .unknown: return "Carte"
        }
    }
    var tint: UInt {
        switch self {
        case .visa: return 0x1A1F71
        case .mastercard: return 0xEB001B
        case .amex: return 0x2E77BC
        case .unknown: return 0x5A6178
        }
    }
}

/// A remembered card — masked only (no full PAN, no CVV). A real integration
/// would store the processor's reusable token here instead.
struct SavedCard: Codable, Identifiable, Hashable {
    var id = UUID()
    let brand: CardBrand
    let last4: String
    let expiry: String   // MM/AA
}

struct Invoice: Codable, Identifiable, Hashable {
    var id = UUID()
    let number: String
    let ticketReference: String
    let amount: Int
    let method: String
    let payer: String
    let authCode: String
    let date: Date
}

protocol PaymentService {
    /// Authorize a charge. `pan` is the raw card number (nil for Apple Pay).
    /// Returns an authorization code on success, throws `PaymentError` otherwise.
    func authorize(amount: Int, method: PaymentMethod, pan: String?) async throws -> String
}

// MARK: - Sandbox test cards

/// Well-known test cards that drive a deterministic outcome — mirrors how real
/// gateway sandboxes (Stripe/CMI) work, so QA covers every branch with no money.
enum SandboxCard: String, CaseIterable, Identifiable {
    case approved      = "4242424242424242"
    case declined      = "4000000000000002"
    case insufficient  = "4000000000009995"
    case threeDSecure  = "4000000000003220"

    var id: String { rawValue }

    /// Grouped 4-4-4-4 for display / field entry.
    var formatted: String { stride(from: 0, to: rawValue.count, by: 4).map {
        let s = rawValue.index(rawValue.startIndex, offsetBy: $0)
        let e = rawValue.index(s, offsetBy: 4, limitedBy: rawValue.endIndex) ?? rawValue.endIndex
        return String(rawValue[s..<e])
    }.joined(separator: " ") }

    /// French label (localised via L() at the call site).
    var label: String {
        switch self {
        case .approved:     return "Approuvée"
        case .declined:     return "Refusée"
        case .insufficient: return "Fonds insuffisants"
        case .threeDSecure: return "3-D Secure"
        }
    }
}

/// Demo processor with realistic latency and outcomes. Replace with CMI/Stripe.
struct SandboxPaymentProcessor: PaymentService {
    func authorize(amount: Int, method: PaymentMethod, pan: String?) async throws -> String {
        // Apple Pay carries no PAN here — always approves in the sandbox.
        if method == .applePay {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return Self.authCode()
        }
        let digits = (pan ?? "").filter(\.isNumber)
        try await Task.sleep(nanoseconds: 1_200_000_000)   // simulate the network round-trip

        switch SandboxCard(rawValue: digits) {
        case .declined:      throw PaymentError.declined
        case .insufficient:  throw PaymentError.insufficientFunds
        case .threeDSecure:
            // Simulate the extra 3-D Secure challenge step, then approve.
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return Self.authCode()
        case .approved, .none:
            return Self.authCode()   // 4242… and any other valid card → approved
        }
    }

    private static func authCode() -> String {
        "AUTH-" + String(UUID().uuidString.prefix(8)).uppercased()
    }
}

enum InvoiceFactory {
    static func make(ticketRef: String, amount: Int, method: PaymentMethod,
                     payer: String, authCode: String) -> Invoice {
        let num = "FA-" + String(Int(Date().timeIntervalSince1970)).suffix(8)
        return Invoice(number: String(num), ticketReference: ticketRef, amount: amount,
                       method: method.rawValue, payer: payer, authCode: authCode, date: Date())
    }
}
