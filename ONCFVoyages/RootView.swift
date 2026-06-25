//
//  RootView.swift
//  Tab bar shell + first-run onboarding gate.
//

import SwiftUI

struct RootView: View {
    @State private var selection = RootView.initialTab
    @AppStorage("seenOnboarding") private var seenOnboarding = false
    @State private var onboardingDone = false
    @StateObject private var conn = Connectivity()

    /// Allows launching straight onto a tab via `-tab <index>` (used for previews/testing).
    static var initialTab: Int {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let n = Int(args[i + 1]) { return n }
        return 0
    }

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                HomeView()
                    .tabItem { Label(L("Accueil"), systemImage: "house.fill") }.tag(0)
                HorairesView()
                    .tabItem { Label(L("Horaires"), systemImage: "clock.fill") }.tag(1)
                TicketsView()
                    .tabItem { Label(L("Billets"), systemImage: "ticket.fill") }.tag(2)
                TrackView()
                    .tabItem { Label(L("Suivi"), systemImage: "location.fill") }.tag(3)
                CardView()
                    .tabItem { Label(L("Carte"), systemImage: "creditcard.fill") }.tag(4)
            }

            if !seenOnboarding && !onboardingDone {
                OnboardingView(done: $onboardingDone)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .safeAreaInset(edge: .top) {
            if !conn.isOnline {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash").font(.caption.weight(.bold))
                    Text(L("Mode hors-ligne · vos billets restent accessibles"))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Brand.ink)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: conn.isOnline)
    }
}

#Preview {
    RootView().environmentObject(AppStore())
}
