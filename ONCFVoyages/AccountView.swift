//
//  AccountView.swift
//  Edit profile · change password · delete account (App-Store required).
//

import SwiftUI

struct AccountView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var name = ""
    @State private var current = ""
    @State private var newPass = ""
    @State private var saved = false
    @State private var pwMsg: String?
    @State private var showDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Mon profil")).font(.headline).foregroundStyle(Brand.label)
                        labeled(L("Nom complet")) { TextField(auth.user?.name ?? "", text: $name).fieldStyle() }
                        labeled(L("E-mail")) {
                            Text(auth.user?.email ?? "—").foregroundStyle(Brand.textSoft).fieldStyle()
                        }
                        Button {
                            Task { await auth.updateName(name.isEmpty ? (auth.user?.name ?? "") : name); saved = true }
                        } label: { Text(saved ? "✓ \(L("Enregistré"))" : L("Enregistrer")) }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || auth.busy)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Changer le mot de passe")).font(.headline).foregroundStyle(Brand.label)
                        labeled(L("Mot de passe actuel")) { SecureField("••••••", text: $current).fieldStyle() }
                        labeled(L("Nouveau mot de passe")) { SecureField("••••••", text: $newPass).fieldStyle() }
                        if let pwMsg { Text(pwMsg).font(.caption).foregroundStyle(pwMsg.hasPrefix("✓") ? .green : .red) }
                        Button {
                            Task {
                                let ok = await auth.changePassword(current: current, new: newPass)
                                pwMsg = ok ? "✓ Mot de passe modifié" : (auth.error ?? "Erreur")
                                if ok { current = ""; newPass = "" }
                            }
                        } label: { Text(L("Changer le mot de passe")) }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(current.isEmpty || newPass.isEmpty || auth.busy)
                    }
                }

                Button(role: .destructive) { showDelete = true } label: {
                    Label(L("Supprimer mon compte"), systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.red.opacity(0.1), in: Capsule())
                        .foregroundStyle(.red)
                }
            }
            .padding(18)
        }
        .background(Brand.sand.ignoresSafeArea())
        .navigationTitle(L("Compte"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L("Supprimer mon compte"), isPresented: $showDelete, titleVisibility: .visible) {
            Button("Supprimer définitivement", role: .destructive) { Task { await auth.deleteAccount() } }
            Button(L("Annuler"), role: .cancel) {}
        } message: {
            Text("Cette action est irréversible. Votre compte et vos données seront supprimés.")
        }
        .onAppear { name = auth.user?.name ?? "" }
    }

    private func labeled<V: View>(_ label: String, @ViewBuilder _ content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
            content()
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        self.padding(.vertical, 11).padding(.horizontal, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview { NavigationStack { AccountView() }.environmentObject(AuthViewModel()) }
