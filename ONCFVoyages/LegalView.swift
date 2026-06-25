//
//  LegalView.swift
//  Privacy policy · terms (CGV) · support — required for App Store.
//

import SwiftUI

struct LegalView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section(L("Politique de confidentialité"), icon: "lock.shield.fill", body:
"""
ONCF Voyages collecte uniquement les données nécessaires à la réservation et à \
l'émission de vos billets (identité, e-mail, trajets). Vos données ne sont jamais \
vendues. Le paiement est traité de manière chiffrée par notre prestataire agréé. \
Vous pouvez consulter, modifier ou supprimer votre compte et vos données à tout \
moment depuis l'écran Compte.
""")
                section(L("Conditions générales"), icon: "doc.text.fill", body:
"""
Les billets sont nominatifs et non cessibles. L'échange et le remboursement sont \
possibles selon les conditions affichées au moment de l'opération (remboursement \
intégral plus de 24h avant le départ, frais de 10% en deçà, non remboursable à moins \
d'1h). Le voyageur doit présenter une pièce d'identité valide à bord. ONCF se réserve \
le droit de modifier les horaires en cas de force majeure.
""")
                section(L("Aide & contact"), icon: "questionmark.circle.fill", body:
"""
Service client ONCF : 2255 (appel local).
E-mail : contact@oncf-voyages.ma
Du lundi au samedi, 8h–20h.
""")
                Text("© 2026 ONCF — Office National des Chemins de Fer.")
                    .font(.caption2).foregroundStyle(Brand.textSoft)
            }
            .padding(20)
        }
        .background(Brand.sand.ignoresSafeArea())
        .navigationTitle(L("Aide & contact"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, icon: String, body: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.headline).foregroundStyle(Brand.label)
                Text(body).font(.subheadline).foregroundStyle(Brand.textSoft)
            }
        }
    }
}

#Preview { NavigationStack { LegalView() } }
