//
//  ConfirmEmailView.swift
//  Verify a new account with the e-mailed numeric code (no links).
//

import SwiftUI

struct ConfirmEmailView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    let email: String
    @State private var code = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "envelope.badge.fill").font(.system(size: 34)).foregroundStyle(Brand.orange)
                        Text(L("Vérifiez votre e-mail"))
                            .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Brand.label)
                        Text(String(format: L("Saisissez le code à 6 chiffres envoyé à %@."), email))
                            .font(.subheadline).foregroundStyle(Brand.textSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Code de vérification").uppercased())
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
                        TextField("123456", text: $code)
                            .keyboardType(.numberPad)
                            .font(.system(.title3, design: .monospaced)).tracking(6)
                            .padding(.vertical, 13).padding(.horizontal, 14)
                            .background(Brand.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.black.opacity(0.08)))
                            .accessibilityLabel(Text(L("Code de vérification")))
                    }

                    if let e = error {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            guard code.filter(\.isNumber).count >= 4 else { error = L("Code incorrect."); return }
                            error = nil
                            let ok = await auth.confirmSignup(email: email, code: code)
                            if ok { Haptics.success() } else { error = auth.error; Haptics.error() }
                        }
                    } label: {
                        HStack {
                            if auth.busy { ProgressView().tint(.white) }
                            Text(auth.busy ? L("Vérification…") : L("Confirmer mon compte"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(auth.busy)

                    Text(L("Vérifiez aussi vos spams. Le code peut prendre une minute."))
                        .font(.caption2).foregroundStyle(Brand.textSoft)
                }
                .padding(20)
            }
            .background(Brand.sand.ignoresSafeArea())
            .navigationTitle(L("Confirmer l'e-mail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Fermer")) { dismiss() } } }
        }
    }
}

#Preview { ConfirmEmailView(email: "vous@email.com").environmentObject(AuthViewModel()) }
