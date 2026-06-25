//
//  AppLock.swift
//  Optional Face ID / Touch ID lock that guards tickets and saved payment data.
//

import SwiftUI
import LocalAuthentication

/// Drives the app-lock state. When the user enables biometric lock, the app
/// covers its content whenever it returns from the background until the owner
/// re-authenticates with Face ID / Touch ID (passcode as fallback).
final class LockManager: ObservableObject {
    @AppStorage("biometricLockEnabled") var enabled = false {
        didSet { if !enabled { locked = false } }
    }
    /// True while the cover screen should be shown.
    @Published var locked = false
    /// True while an evaluation is in flight (avoids double prompts).
    @Published var authenticating = false

    /// Whether the device can actually do biometrics (hides the toggle otherwise).
    var isAvailable: Bool {
        var err: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    var biometryType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    var biometryName: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return L("Code")
        }
    }

    var biometryIcon: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    /// Cover the app (call when entering the background or right after sign-in).
    func lockIfNeeded() {
        if enabled && isAvailable { locked = true }
    }

    /// Prompt for biometrics and reveal the app on success.
    func unlock() {
        guard locked, !authenticating else { return }
        guard enabled, isAvailable else { locked = false; return }
        authenticating = true
        let ctx = LAContext()
        let reason = L("Déverrouillez vos billets")
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
            DispatchQueue.main.async {
                self.authenticating = false
                if ok { self.locked = false }
            }
        }
    }
}

/// Full-screen cover shown while the app is locked.
struct LockView: View {
    @EnvironmentObject var lock: LockManager

    var body: some View {
        ZStack {
            Brand.inkGrad.ignoresSafeArea()
            RadialGradient(colors: [Brand.orange.opacity(0.35), .clear],
                           center: .top, startRadius: 0, endRadius: 360).ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                LogoMark(size: 64)
                Text("ONCF ").font(.system(.title, design: .rounded).weight(.bold)).foregroundColor(.white)
                + Text("voyages").font(.system(.title, design: .rounded)).foregroundColor(.white.opacity(0.7))

                Image(systemName: lock.biometryIcon)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Brand.orange2)
                    .padding(.top, 8)
                Text(L("Application verrouillée"))
                    .font(.headline).foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button { lock.unlock() } label: {
                    Label(String(format: L("Déverrouiller avec %@"), lock.biometryName),
                          systemImage: lock.biometryIcon)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .onAppear { lock.unlock() }
    }
}
