//
//  ONCFVoyagesApp.swift
//  ONCF Voyages — train companion app for ONCF (Morocco) travellers.
//
//  SwiftUI · iOS 16+
//

import SwiftUI
import UserNotifications

@main
struct ONCFVoyagesApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var auth = AuthViewModel()
    @StateObject private var lang = LanguageManager()
    @StateObject private var lock = LockManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Gate()
                .environmentObject(store)
                .environmentObject(auth)
                .environmentObject(lang)
                .environmentObject(lock)
                .environment(\.layoutDirection, lang.lang.isRTL ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: lang.lang.rawValue))
                .id(lang.lang)                 // rebuild so L() re-evaluates on switch
                .tint(Brand.orange)            // follows system light/dark
        }
        .onChange(of: scenePhase) { phase in
            // Re-cover the app the moment it leaves the foreground.
            if phase == .background { lock.lockIfNeeded() }
        }
    }
}

/// Shows the auth screen until the user is signed in, then the app.
struct Gate: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var lock: LockManager

    var body: some View {
        ZStack {
            Group {
                if auth.user != nil {
                    RootView()
                } else {
                    AuthView()
                }
            }
            // Biometric cover sits above everything when locked.
            if auth.user != nil && lock.locked {
                LockView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lock.locked)
        .onAppear {
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
            if let u = auth.user { store.memberName = u.name; lock.lockIfNeeded() }
        }
        .onChange(of: auth.user) { newValue in
            if let u = newValue { store.memberName = u.name; lock.lockIfNeeded() }
        }
    }
}
