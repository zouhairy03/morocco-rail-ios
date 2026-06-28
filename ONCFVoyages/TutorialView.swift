//
//  TutorialView.swift
//  "How to use the app" walkthrough shown to each brand-new account.
//

import SwiftUI

struct TutorialView: View {
    let onDone: () -> Void
    @State private var page = 0

    private let pages: [(icon: String, title: String, text: String)] = [
        ("magnifyingglass", "Cherchez votre trajet",
         "Choisissez départ, arrivée et date sur l'accueil, puis lancez la recherche."),
        ("tram.fill", "Réservez en quelques secondes",
         "Sélectionnez un train, vos voyageurs et votre place, puis payez en toute sécurité."),
        ("qrcode", "Votre e-billet",
         "Retrouvez votre billet avec QR code dans l'onglet Billets, et téléchargez-le en PDF."),
        ("location.fill", "Suivez votre train",
         "Dans Suivi, voyez la position de votre train en direct et votre distance par rapport à lui."),
        ("creditcard.fill", "Carte & fidélité",
         "Gérez votre profil, votre carte de réduction et vos points dans l'onglet Carte.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("Comment ça marche")).font(.headline).foregroundStyle(Brand.label)
                Spacer()
                Button(L("Passer")) { finish() }.font(.subheadline).foregroundStyle(Brand.textSoft)
            }
            .padding(.horizontal, 22).padding(.top, 20)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    VStack(spacing: 22) {
                        Spacer()
                        ZStack {
                            Circle().fill(Brand.orange.opacity(0.12)).frame(width: 150, height: 150)
                            Image(systemName: pages[i].icon)
                                .font(.system(size: 58, weight: .bold))
                                .foregroundStyle(Brand.warm)
                        }
                        Text("\(i + 1). \(L(pages[i].title))")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(Brand.label).multilineTextAlignment(.center)
                        Text(L(pages[i].text))
                            .font(.body).foregroundStyle(Brand.textSoft)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                        Spacer()
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < pages.count - 1 { withAnimation { page += 1 } } else { finish() }
            } label: {
                Text(page < pages.count - 1 ? L("Suivant") : L("Commencer"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24).padding(.bottom, 28)
        }
        .background(Brand.sand.ignoresSafeArea())
    }

    private func finish() { Haptics.tap(); onDone() }
}

#Preview { TutorialView(onDone: {}) }
