//
//  WelcomeFlowView.swift
//  Shown once to each brand-new account after e-mail verification:
//  "e-mail verified" celebration → personalised welcome → animated tutorial.
//

import SwiftUI

struct WelcomeFlowView: View {
    let name: String
    let onDone: () -> Void

    private enum Phase: Int { case verified, welcome, tutorial }
    @State private var phase: Phase = .verified

    private var firstName: String {
        let n = name.split(separator: " ").first.map(String.init) ?? ""
        return n.isEmpty ? L("voyageur") : n
    }

    var body: some View {
        ZStack {
            AnimatedBackdrop()
            Group {
                switch phase {
                case .verified:
                    VerifiedCard { advance(to: .welcome) }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .move(edge: .leading))))
                case .welcome:
                    WelcomeCard(name: firstName) { advance(to: .tutorial) }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))))
                case .tutorial:
                    AnimatedTutorial(onDone: onDone)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.9), value: phase)
    }

    /// Forward-only so a late auto-advance timer can never jump the flow backwards.
    private func advance(to p: Phase) {
        guard p.rawValue > phase.rawValue else { return }
        phase = p
    }
}

// MARK: - Soft animated backdrop

struct AnimatedBackdrop: View {
    @State private var drift = false
    var body: some View {
        ZStack {
            Brand.sand.ignoresSafeArea()
            Circle().fill(Brand.orange.opacity(0.18)).frame(width: 340, height: 340)
                .blur(radius: 90).offset(x: drift ? -120 : -70, y: drift ? -280 : -330)
            Circle().fill(Brand.gold.opacity(0.16)).frame(width: 320, height: 320)
                .blur(radius: 100).offset(x: drift ? 140 : 100, y: drift ? 330 : 380)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

// MARK: - 1 · E-mail verified celebration

struct VerifiedCard: View {
    let onContinue: () -> Void
    @State private var ring = false
    @State private var pop = false
    @State private var burst = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(Brand.orange.opacity(0.18), lineWidth: 10).frame(width: 150, height: 150)
                Circle().trim(from: 0, to: ring ? 1 : 0)
                    .stroke(Brand.warm, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 150, height: 150).rotationEffect(.degrees(-90))
                Image(systemName: "checkmark")
                    .font(.system(size: 58, weight: .heavy)).foregroundStyle(Brand.orange)
                    .scaleEffect(pop ? 1 : 0.2).opacity(pop ? 1 : 0)
                ForEach(0..<10, id: \.self) { i in
                    Circle().fill(i.isMultiple(of: 2) ? Brand.orange : Brand.gold)
                        .frame(width: 9, height: 9)
                        .offset(y: burst ? -108 : -52)
                        .rotationEffect(.degrees(Double(i) / 10 * 360))
                        .opacity(burst ? 0 : 1)
                        .scaleEffect(burst ? 0.3 : 1)
                }
            }
            .frame(height: 160)

            Text(L("E-mail vérifié !"))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Brand.label)
                .opacity(pop ? 1 : 0).offset(y: pop ? 0 : 12)
            Text(L("Votre compte est prêt."))
                .font(.subheadline).foregroundStyle(Brand.textSoft)
                .opacity(pop ? 1 : 0)
        }
        .padding(40)
        .contentShape(Rectangle())
        .onTapGesture { onContinue() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { ring = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.3)) { pop = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.35)) { burst = true }
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { onContinue() }
        }
    }
}

// MARK: - 2 · Personalised welcome

struct WelcomeCard: View {
    let name: String
    let onContinue: () -> Void
    @State private var show = false
    @State private var wave = false

    var body: some View {
        VStack(spacing: 14) {
            Text("👋").font(.system(size: 66))
                .rotationEffect(.degrees(wave ? 12 : -12), anchor: .bottomTrailing)
                .scaleEffect(show ? 1 : 0.4)
            Text(L("Bienvenue"))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Brand.textSoft)
                .opacity(show ? 1 : 0)
            Text(name)
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(Brand.label)
                .opacity(show ? 1 : 0).offset(y: show ? 0 : 18)
            Text(L("Votre voyage commence ici."))
                .font(.subheadline).foregroundStyle(Brand.textSoft)
                .opacity(show ? 1 : 0)
        }
        .padding(40)
        .contentShape(Rectangle())
        .onTapGesture { onContinue() }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { show = true }
            withAnimation(.easeInOut(duration: 0.5).repeatCount(4, autoreverses: true)) { wave = true }
            Haptics.tap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { onContinue() }
        }
    }
}

// MARK: - 3 · Animated tutorial

struct AnimatedTutorial: View {
    let onDone: () -> Void
    @State private var page = 0
    @State private var animate = false

    private let pages: [(icon: String, title: String, text: String)] = [
        ("magnifyingglass", "Cherchez votre trajet",
         "Choisissez départ, arrivée et date sur l'accueil, puis lancez la recherche."),
        ("tram.fill", "Réservez en quelques secondes",
         "Sélectionnez un train, vos voyageurs et votre place, puis payez en toute sécurité."),
        ("qrcode", "Votre e-billet",
         "Retrouvez votre billet avec QR code dans l'onglet Billets, et téléchargez-le en PDF."),
        ("location.fill", "Suivez votre train",
         "Dans Suivi, voyez la position de votre train en direct sur la carte."),
        ("creditcard.fill", "Carte & fidélité",
         "Gérez votre profil, votre carte de réduction et vos points dans l'onglet Carte.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // progress segments
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= page ? AnyShapeStyle(Brand.warm) : AnyShapeStyle(Color.black.opacity(0.1)))
                        .frame(height: 4).frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24).padding(.top, 22)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)

            HStack {
                Spacer()
                Button(L("Passer")) { finish() }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.textSoft)
            }
            .padding(.horizontal, 24).padding(.top, 10)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(i).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            Button {
                if page < pages.count - 1 { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { page += 1 } }
                else { finish() }
            } label: {
                Text(page < pages.count - 1 ? L("Suivant") : L("Commencer")).frame(maxWidth: .infinity)
            }
            .buttonStyle(DarkPillStyle())
            .padding(.horizontal, 24).padding(.bottom, 30)
        }
        .background(Brand.sand.ignoresSafeArea())
        .onAppear { retrigger() }
        .onChange(of: page) { _ in retrigger() }
    }

    private func pageView(_ i: Int) -> some View {
        let current = page == i
        return VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle().fill(Brand.cream).frame(width: 176, height: 176)
                    .shadow(color: Brand.ink.opacity(0.10), radius: 22, y: 12)
                Circle().fill(Brand.orange.opacity(0.12)).frame(width: 176, height: 176)
                Image(systemName: pages[i].icon)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Brand.warm)
                    .scaleEffect(current && animate ? 1 : 0.55)
                    .rotationEffect(.degrees(current && animate ? 0 : -14))
            }
            VStack(spacing: 10) {
                Text(L(pages[i].title))
                    .font(.system(.title, design: .rounded).weight(.heavy))
                    .foregroundStyle(Brand.label).multilineTextAlignment(.center)
                Text(L(pages[i].text))
                    .font(.body).foregroundStyle(Brand.textSoft)
                    .multilineTextAlignment(.center).padding(.horizontal, 34)
            }
            .opacity(current && animate ? 1 : 0)
            .offset(y: current && animate ? 0 : 16)
            Spacer()
        }
        .padding(.top, 10)
    }

    private func retrigger() {
        animate = false
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.06)) { animate = true }
        Haptics.select()
    }

    private func finish() { Haptics.tap(); onDone() }
}

#Preview {
    WelcomeFlowView(name: "Youssef Zouhair") {}
}
