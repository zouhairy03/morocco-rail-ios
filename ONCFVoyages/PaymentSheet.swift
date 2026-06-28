//
//  PaymentSheet.swift
//  Payment UI: Apple Pay button + card form, with real processing states.
//

import SwiftUI
import PassKit
import LocalAuthentication

struct PaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let amount: Int
    let payer: String
    /// Called on success with the authorization code and method used.
    var onSuccess: (String, PaymentMethod) -> Void

    @EnvironmentObject private var store: AppStore
    private let processor: PaymentService = SandboxPaymentProcessor()
    @State private var busy = false
    @State private var stage = ""        // e.g. "3-D Secure…" while challenging
    @State private var error: String?
    @State private var card = ""
    @State private var expiry = ""
    @State private var cvv = ""
    @State private var selectedCard: SavedCard?   // a remembered card chosen for this pay
    @State private var saveCard = true            // remember a newly entered card

    private var brand: CardBrand { CardBrand.detect(card) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Card {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "testtube.2").font(.system(size: 9, weight: .bold))
                                Text("SANDBOX").font(.system(size: 9, weight: .bold)).tracking(1)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Brand.clay, in: Capsule())
                            Text(L("MONTANT À PAYER")).font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
                            Text(Fmt.price(amount)).font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(Brand.label)
                            Text(L("Mode test · aucun argent réel")).font(.caption).foregroundStyle(Brand.textSoft)
                        }.frame(maxWidth: .infinity)
                    }

                    if PKPaymentAuthorizationController.canMakePayments() {
                        ApplePayButton { pay(.applePay) }
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .allowsHitTesting(!busy)
                        HStack { line; Text(L("ou par carte")).font(.caption).foregroundStyle(Brand.textSoft); line }
                    }

                    if !store.savedCards.isEmpty { savedCardsSection }

                    if selectedCard == nil {
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                cardNumberField
                                HStack(spacing: 12) {
                                    field("Expiration", text: $expiry, placeholder: "MM/AA")
                                    field("CVV", text: $cvv, placeholder: "123")
                                }
                                Toggle(isOn: $saveCard) {
                                    Text(L("Enregistrer cette carte")).font(.caption).foregroundStyle(Brand.textSoft)
                                }
                                .tint(Brand.orange)
                            }
                        }
                        testCards
                    }

                    if let e = error {
                        Label(e, systemImage: "exclamationmark.circle.fill")
                            .font(.caption).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button { pay(.card) } label: {
                        HStack {
                            if busy { ProgressView().tint(.white) }
                            Text(busy ? (stage.isEmpty ? L("Traitement…") : stage) : "\(L("Payer")) \(Fmt.price(amount))")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy)

                    Label(L("Chiffré · 3-D Secure"), systemImage: "lock.fill")
                        .font(.caption2).foregroundStyle(Brand.textSoft)
                }
                .padding(20)
            }
            .background(Brand.sand.ignoresSafeArea())
            .navigationTitle(L("Paiement"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Annuler")) { dismiss() }.disabled(busy)
                }
            }
        }
        .interactiveDismissDisabled(busy)
    }

    private var line: some View { Rectangle().fill(Color.black.opacity(0.1)).frame(height: 1) }

    private func luhn(_ s: String) -> Bool {
        let digits = s.compactMap { $0.wholeNumberValue }
        guard digits.count >= 12 else { return false }
        var sum = 0
        for (i, d) in digits.reversed().enumerated() {
            if i % 2 == 1 { let x = d * 2; sum += x > 9 ? x - 9 : x } else { sum += d }
        }
        return sum % 10 == 0
    }
    private func expiryValid(_ s: String) -> Bool {
        let p = s.split(separator: "/")
        guard p.count == 2, let m = Int(p[0]), Int(p[1]) != nil, (1...12).contains(m) else { return false }
        return true
    }

    private func pay(_ method: PaymentMethod) {
        guard !busy else { return }

        // Apple Pay must be confirmed by the owner. The real system sheet (side-
        // button double-click + Face ID) needs a Merchant ID + the Apple Pay
        // entitlement; until that's set up we require Face ID / Touch ID here.
        if method == .applePay {
            verifyBiometric { ok in
                if ok { authorizeAndFinish(method: .applePay, pan: nil, save: nil) }
            }
            return
        }

        // Pay with a remembered (tokenized) card.
        if selectedCard != nil {
            authorizeAndFinish(method: .card, pan: nil, save: nil)
            return
        }

        // New card: validate then charge.
        let digits = card.filter(\.isNumber)
        guard digits.count >= 13, luhn(digits) else { error = L("Numéro de carte invalide."); return }
        guard expiryValid(expiry) else { error = L("Date d'expiration invalide (MM/AA)."); return }
        guard cvv.filter(\.isNumber).count >= 3 else { error = L("Code CVV invalide."); return }
        stage = (SandboxCard(rawValue: digits) == .threeDSecure) ? L("3-D Secure…") : ""
        let masked = saveCard ? SavedCard(brand: brand, last4: String(digits.suffix(4)), expiry: expiry) : nil
        authorizeAndFinish(method: .card, pan: digits, save: masked)
    }

    private func authorizeAndFinish(method: PaymentMethod, pan: String?, save: SavedCard?) {
        busy = true; error = nil
        Task {
            do {
                let code = try await processor.authorize(amount: amount, method: method, pan: pan)
                busy = false; stage = ""
                if let m = save { store.saveCard(m) }
                Haptics.success()
                onSuccess(code, method)
                dismiss()
            } catch {
                busy = false; stage = ""
                Haptics.error()
                self.error = (error as? LocalizedError)?.errorDescription ?? L("Paiement échoué.")
            }
        }
    }

    /// Face ID / Touch ID confirmation (passcode fallback). Proceeds anyway if the
    /// device has no biometrics enrolled, so the sandbox stays testable.
    private func verifyBiometric(_ completion: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { completion(true); return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L("Confirmez le paiement Apple Pay")) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    /// One-tap test cards that drive each sandbox outcome.
    private var testCards: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard.and.123").font(.caption).foregroundStyle(Brand.clay)
                    Text(L("Cartes de test")).font(.caption.weight(.bold)).foregroundStyle(Brand.textSoft)
                    Spacer()
                    Text(L("Toucher pour remplir")).font(.caption2).foregroundStyle(Brand.textSoft)
                }
                ForEach(SandboxCard.allCases) { c in
                    Button {
                        card = c.formatted; expiry = "12/30"; cvv = "123"; error = nil
                        Haptics.select()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: dotIcon(c)).font(.caption).foregroundStyle(dotColor(c))
                            Text(c.formatted).font(.system(.footnote, design: .monospaced)).foregroundStyle(Brand.label)
                            Spacer()
                            Text(L(c.label)).font(.caption2.weight(.semibold)).foregroundStyle(dotColor(c))
                        }
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(dotColor(c).opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Card-number field with a live brand badge (Visa / Mastercard / Amex).
    private var cardNumberField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Numéro de carte").uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
            HStack {
                TextField("4242 4242 4242 4242", text: $card)
                    .keyboardType(.numbersAndPunctuation)
                    .accessibilityLabel(Text(L("Numéro de carte")))
                if !card.isEmpty {
                    Text(brand.name)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color(hex: brand.tint), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
            .padding(.vertical, 11).padding(.horizontal, 13)
            .background(Brand.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    /// Remembered cards — pick one to pay in a tap; swipe-free delete button.
    private var savedCardsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("Mes cartes")).font(.caption.weight(.bold)).foregroundStyle(Brand.textSoft)
                ForEach(store.savedCards) { c in
                    HStack(spacing: 10) {
                        Text(c.brand.name)
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                            .frame(width: 52).padding(.vertical, 5)
                            .background(Color(hex: c.brand.tint), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        Text("•••• \(c.last4)").font(.system(.subheadline, design: .monospaced)).foregroundStyle(Brand.label)
                        Spacer()
                        Text(c.expiry).font(.caption2).foregroundStyle(Brand.textSoft)
                        Image(systemName: selectedCard?.id == c.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedCard?.id == c.id ? Brand.orange : Brand.textSoft)
                        Button { store.removeCard(c); if selectedCard?.id == c.id { selectedCard = nil } } label: {
                            Image(systemName: "trash").font(.caption).foregroundStyle(Brand.textSoft)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(L("Supprimer")))
                    }
                    .padding(.vertical, 8).padding(.horizontal, 10)
                    .background(selectedCard?.id == c.id ? Brand.orange.opacity(0.08) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCard = (selectedCard?.id == c.id) ? nil : c
                        error = nil
                    }
                }
                if selectedCard != nil {
                    Button { selectedCard = nil } label: {
                        Label(L("Utiliser une autre carte"), systemImage: "plus.circle")
                            .font(.caption.weight(.semibold)).foregroundStyle(Brand.orange)
                    }
                }
            }
        }
    }

    private func dotColor(_ c: SandboxCard) -> Color {
        switch c {
        case .approved:     return Color(hex: 0x16A34A)
        case .declined, .insufficient: return .red
        case .threeDSecure: return Brand.orange
        }
    }
    private func dotIcon(_ c: SandboxCard) -> String {
        switch c {
        case .approved:     return "checkmark.circle.fill"
        case .declined:     return "xmark.circle.fill"
        case .insufficient: return "exclamationmark.circle.fill"
        case .threeDSecure: return "lock.shield.fill"
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L(label).uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
            TextField(placeholder, text: text)
                .keyboardType(.numbersAndPunctuation)
                .padding(.vertical, 11).padding(.horizontal, 13)
                .background(Brand.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(Text(label))
        }
    }
}

/// Native Apple Pay button. NOTE: a real charge needs a Merchant ID + PassKit
/// authorization + server capture; here it routes through the demo processor.
struct ApplePayButton: UIViewRepresentable {
    var action: () -> Void
    func makeUIView(context: Context) -> PKPaymentButton {
        let b = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
        b.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return b
    }
    func updateUIView(_ uiView: PKPaymentButton, context: Context) { context.coordinator.action = action }
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
