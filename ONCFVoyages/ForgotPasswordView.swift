//
//  ForgotPasswordView.swift
//  Password reset with e-mail verification.
//
//  Flow: enter e-mail → (code + new password) → done.
//  When Supabase is configured the code is e-mailed and verified server-side;
//  otherwise the local/demo path shows the code in-app. Same screens either way.
//

import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    enum Step { case email, reset, done }
    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    switch step {
                    case .email: emailStep
                    case .reset: resetStep
                    case .done:  doneStep
                    }
                    if let e = error {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(Brand.sand.ignoresSafeArea())
            .navigationTitle(L("Mot de passe oublié"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Fermer")) { dismiss() } } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: stepIcon).font(.system(size: 34)).foregroundStyle(Brand.orange)
            Text(stepTitle).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Brand.label)
            Text(stepSubtitle).font(.subheadline).foregroundStyle(Brand.textSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Steps

    private var emailStep: some View {
        VStack(spacing: 14) {
            field(L("E-mail"), text: $email, placeholder: "vous@email.com", keyboard: .emailAddress)
            primary(L("Envoyer le code")) { sendCode() }
        }
    }

    private var resetStep: some View {
        VStack(spacing: 14) {
            // Demo path shows the code; the real (Supabase) path e-mails it.
            if let demo = auth.resetDemoCode {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.badge.fill").foregroundStyle(Brand.clay)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Mode démo — code de vérification")).font(.caption2.weight(.bold)).foregroundStyle(Brand.clay)
                        Text(demo).font(.system(.title3, design: .monospaced).weight(.bold)).foregroundStyle(Brand.label).tracking(4)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(hex: 0xFFF4EA), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Label(L("Un code a été envoyé à votre e-mail."), systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(Color(hex: 0x16A34A))
            }

            field(L("Code de vérification"), text: $code, placeholder: "123456", keyboard: .numberPad)
            field(L("Nouveau mot de passe"), text: $newPassword, placeholder: "••••••", secure: true)
            primary(auth.busy ? L("Enregistrement…") : L("Réinitialiser")) { reset() }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(Color(hex: 0x16A34A))
            Text(L("Mot de passe mis à jour")).font(.headline).foregroundStyle(Brand.label)
            primary(L("Retour à la connexion")) { dismiss() }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    // MARK: Actions

    private func sendCode() {
        let e = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard e.contains("@"), e.contains(".") else { error = L("Adresse e-mail invalide."); return }
        error = nil; Haptics.tap()
        Task {
            let ok = await auth.sendResetCode(email: e)
            if ok { withAnimation { step = .reset } } else { error = auth.error }
        }
    }

    private func reset() {
        guard code.filter(\.isNumber).count >= 4 else { error = L("Code incorrect."); return }
        guard newPassword.count >= 6 else { error = L("Le mot de passe doit faire au moins 6 caractères."); return }
        error = nil
        Task {
            let ok = await auth.confirmReset(email: email, code: code, newPassword: newPassword)
            if ok { Haptics.success(); withAnimation { step = .done } }
            else { error = auth.error; Haptics.error() }
        }
    }

    // MARK: Bits

    private var stepIcon: String {
        switch step {
        case .email: return "envelope.fill"
        case .reset: return "lock.rotation"
        case .done:  return "checkmark.seal.fill"
        }
    }
    private var stepTitle: String {
        switch step {
        case .email: return L("Réinitialiser le mot de passe")
        case .reset: return L("Entrez le code")
        case .done:  return L("Terminé")
        }
    }
    private var stepSubtitle: String {
        switch step {
        case .email: return L("Saisissez l'e-mail de votre compte, nous vous enverrons un code.")
        case .reset: return L("Saisissez le code reçu puis choisissez un nouveau mot de passe.")
        case .done:  return L("Vous pouvez maintenant vous connecter.")
        }
    }

    private func primary(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).frame(maxWidth: .infinity) }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(auth.busy)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String,
                       secure: Bool = false, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
            Group {
                if secure { SecureField(placeholder, text: text) }
                else { TextField(placeholder, text: text).keyboardType(keyboard).textInputAutocapitalization(.never) }
            }
            .autocorrectionDisabled()
            .padding(.vertical, 13).padding(.horizontal, 14)
            .background(Brand.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.black.opacity(0.08)))
            .accessibilityLabel(Text(label))
        }
    }
}

#Preview { ForgotPasswordView().environmentObject(AuthViewModel()) }
