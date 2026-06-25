//
//  OnboardingView.swift
//  First-run intro.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var done: Bool
    @State private var page = 0

    private let pages: [(icon: String, title: String, text: String)] = [
        ("bolt.fill", "Le Maroc à grande vitesse", "Réservez Al Boraq, Al Atlas et TNR en quelques secondes, partout au Royaume."),
        ("ticket.fill", "Votre billet, dans votre poche", "E-billet avec QR code, choix du siège et carte de réduction. Sans file, sans papier."),
        ("location.fill", "Suivez votre train en direct", "Position en temps réel, quai, et rappel avant le départ.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    VStack(spacing: 22) {
                        Spacer()
                        ZStack {
                            Circle().fill(Brand.orange.opacity(0.12)).frame(width: 160, height: 160)
                            Image(systemName: pages[i].icon)
                                .font(.system(size: 64, weight: .bold))
                                .foregroundStyle(Brand.warm)
                        }
                        Text(L(pages[i].title))
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(Brand.label)
                            .multilineTextAlignment(.center)
                        Text(L(pages[i].text))
                            .font(.body).foregroundStyle(Brand.textSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    UserDefaults.standard.set(true, forKey: "seenOnboarding")
                    withAnimation { done = true }
                }
            } label: {
                Text(page < pages.count - 1 ? L("Suivant") : L("Commencer"))
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            Button(L("Passer")) {
                UserDefaults.standard.set(true, forKey: "seenOnboarding")
                withAnimation { done = true }
            }
            .font(.subheadline)
            .foregroundStyle(Brand.textSoft)
            .padding(.bottom, 16)
        }
        .background(Brand.sand.ignoresSafeArea())
    }
}

#Preview { OnboardingView(done: .constant(false)) }
