//
//  CardView.swift
//  Loyalty card + profile.
//

import SwiftUI

struct CardView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var lang: LanguageManager

    private var tier: String {
        switch store.loyaltyPoints {
        case 2000...: return "Platine"
        case 1000..<2000: return "Or"
        default: return "Argent"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    loyaltyCard
                    stats
                    accountList
                    settingsList
                    languageCard
                    Button(role: .destructive) { auth.signOut() } label: {
                        Label(L("Se déconnecter"), systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.red.opacity(0.1), in: Capsule())
                            .foregroundStyle(Color.red)
                    }
                }
                .padding(18)
            }
            .background(Brand.sand.ignoresSafeArea())
            .navigationTitle(L("Ma carte"))
        }
    }

    private var loyaltyCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Brand.inkGrad)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(RadialGradient(colors: [Brand.orange.opacity(0.5), .clear],
                                     center: .bottomTrailing, startRadius: 0, endRadius: 260))
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("CARTE TARIFA").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    LogoMark(size: 30)
                }
                Spacer()
                Text("\(store.loyaltyPoints)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(L("points fidélité")).font(.caption).foregroundStyle(.white.opacity(0.7))
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MEMBRE").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                        Text(store.memberName).font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(.white)
                    }
                    Spacer()
                    Text(tier)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Brand.label)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Brand.warm, in: Capsule())
                }
            }
            .padding(20)
        }
        .frame(height: 220)
        .shadow(color: Brand.ink.opacity(0.25), radius: 20, y: 12)
    }

    private var stats: some View {
        HStack(spacing: 12) {
            stat("\(store.tickets.count)", "Voyages")
            stat("2 110", "km parcourus")
            stat("8×", "moins de CO₂")
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        Card(padding: 14) {
            VStack(spacing: 4) {
                Text(v).font(.system(.title3, design: .rounded).weight(.heavy)).foregroundStyle(Brand.orange)
                Text(l).font(.caption2).foregroundStyle(Brand.textSoft).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // Account & cards — distinct from settings.
    private var accountList: some View {
        group(L("Compte & cartes")) {
            NavigationLink { AccountView() } label: { row("person.fill", L("Mon profil")) }
            Divider().padding(.leading, 52)
            NavigationLink { ReductionCardView() } label: { row("creditcard.fill", L("Carte de réduction")) }
            Divider().padding(.leading, 52)
            NavigationLink { RewardsView() } label: { row("gift.fill", L("Mes avantages")) }
            Divider().padding(.leading, 52)
            NavigationLink { ReceiptsView() } label: { row("doc.text.fill", L("Mes reçus")) }
        }
    }

    // Settings & support — its own section.
    private var settingsList: some View {
        group(L("Réglages & aide")) {
            NavigationLink { SettingsView() } label: { row("gearshape.fill", L("Réglages")) }
            Divider().padding(.leading, 52)
            NavigationLink { LegalView() } label: { row("questionmark.circle.fill", L("Aide & contact")) }
            Divider().padding(.leading, 52)
            NavigationLink { LegalView() } label: { row("lock.shield.fill", L("Confidentialité")) }
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold)).tracking(1).foregroundStyle(Brand.textSoft)
                .padding(.leading, 6)
            Card(padding: 6) { VStack(spacing: 0) { content() } }
        }
    }

    private var languageCard: some View {
        Card(padding: 6) {
            Menu {
                ForEach(AppLang.allCases) { l in Button(l.label) { lang.lang = l } }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "globe").font(.subheadline).foregroundStyle(Brand.orange)
                        .frame(width: 30, height: 30)
                        .background(Brand.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text(L("Langue")).font(.system(.body, design: .rounded)).foregroundStyle(Brand.label)
                    Spacer()
                    Text(lang.lang.label).font(.subheadline).foregroundStyle(Brand.textSoft)
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Brand.textSoft)
                }
                .padding(.vertical, 12).padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
        }
    }

    private func row(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Brand.orange)
                .frame(width: 30, height: 30)
                .background(Brand.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title).font(.system(.body, design: .rounded)).foregroundStyle(Brand.label)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.textSoft)
        }
        .padding(.vertical, 12).padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}

#Preview { CardView().environmentObject(AppStore()) }
