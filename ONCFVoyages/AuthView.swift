//
//  AuthView.swift
//  Login / sign-up gate — clean, image-led design.
//

import SwiftUI
import UIKit

struct AuthView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = SupabaseConfig.isConfigured ? "" : "demo@oncf.ma"
    @State private var password = SupabaseConfig.isConfigured ? "" : "voyages"
    @State private var showForm = false
    @State private var showReset = false

    enum Mode { case signIn, signUp }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color(light: 0xFFFFFF, dark: 0x0B0E16).ignoresSafeArea()

                // Mosaic grid of photos filling the top, fading into the sheet.
                HeroGrid()
                    .frame(width: geo.size.width, height: geo.size.height * 0.6, alignment: .center)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, Color(light: 0xFFFFFF, dark: 0x0B0E16)],
                                       startPoint: .center, endPoint: .bottom)
                    }
                    .overlay(alignment: .top) {
                        HStack {
                            HStack(spacing: 8) {
                                LogoMark(size: 30)
                                Text("ONCF ").font(.system(.headline, design: .rounded).weight(.bold)).foregroundColor(.white)
                                + Text("voyages").font(.system(.headline, design: .rounded)).foregroundColor(.white.opacity(0.85))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            Spacer()
                            langMenu
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, geo.safeAreaInsets.top + 6)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                sheet
                    .frame(maxWidth: 520)
            }
            .sheet(isPresented: $showReset) {
                ForgotPasswordView().environmentObject(auth)
            }
            .sheet(isPresented: Binding(
                get: { auth.pendingConfirmationEmail != nil },
                set: { if !$0 { auth.pendingConfirmationEmail = nil } })) {
                if let e = auth.pendingConfirmationEmail {
                    ConfirmEmailView(email: e).environmentObject(auth)
                }
            }
        }
    }

    /// Language switcher on the login screen — retranslates the whole app live.
    private var langMenu: some View {
        Menu {
            ForEach(AppLang.allCases) { l in
                Button { lang.lang = l } label: {
                    if lang.lang == l { Label(l.label, systemImage: "checkmark") } else { Text(l.label) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe").font(.caption)
                Text(lang.lang.rawValue.uppercased()).font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityLabel(Text(L("Langue")))
    }

    // MARK: - Bottom sheet (headline + auth controls)

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Bienvenue à bord"))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Brand.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("Réservez vos trains à grande vitesse en quelques secondes."))
                    .font(.subheadline)
                    .foregroundStyle(Brand.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showForm {
                authForm.transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                landingButtons.transition(.opacity)
            }
        }
        .padding(22)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
                .fill(Color(light: 0xFFFFFF, dark: 0x0B0E16))
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showForm)
    }

    // MARK: - Landing (first view): big pill buttons

    private var landingButtons: some View {
        VStack(spacing: 12) {
            Button {
                mode = .signIn
                withAnimation { showForm = true }
            } label: {
                Text(L("Commencer")).frame(maxWidth: .infinity)
            }
            .buttonStyle(DarkPillStyle())

            Button { Task { await auth.signInWithGoogle() } } label: {
                HStack(spacing: 10) {
                    GoogleGlyph(size: 18)
                    Text(L("Continuer avec Google")).font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(LightPillStyle())
            .disabled(auth.busy)

            if let e = auth.error {
                Text(e).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity)
            }

            Text(SupabaseConfig.isConfigured
                 ? L("Créez un compte — vérification par e-mail.")
                 : "Démo : demo@oncf.ma · voyages")
                .font(.caption2).foregroundStyle(Brand.textSoft)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }

    // MARK: - Email / password form

    private var authForm: some View {
        VStack(spacing: 14) {
            Picker("", selection: $mode) {
                Text(L("Connexion")).tag(Mode.signIn)
                Text(L("Inscription")).tag(Mode.signUp)
            }
            .pickerStyle(.segmented)

            if mode == .signUp {
                field(L("Nom complet"), text: $name, placeholder: "Youssef Zouhair")
            }
            field(L("E-mail"), text: $email, placeholder: "vous@email.com", keyboard: .emailAddress)
            field(L("Mot de passe"), text: $password, placeholder: "••••••", secure: true)

            if let e = auth.error {
                Text(e).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task {
                    if mode == .signIn { await auth.signIn(email: email, password: password) }
                    else { await auth.signUp(name: name, email: email, password: password) }
                }
            } label: {
                HStack {
                    if auth.busy { ProgressView().tint(.white) }
                    Text(mode == .signIn ? L("Se connecter") : L("Créer mon compte"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DarkPillStyle())
            .disabled(auth.busy)

            if mode == .signIn {
                Button { showReset = true } label: {
                    Text(L("Mot de passe oublié ?")).font(.caption.weight(.semibold)).foregroundStyle(Brand.clay)
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                divider; Text(L("ou")).font(.caption).foregroundStyle(Brand.textSoft); divider
            }

            Button { Task { await auth.signInWithGoogle() } } label: {
                HStack(spacing: 10) {
                    GoogleGlyph(size: 18)
                    Text(L("Continuer avec Google")).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.label)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Brand.field, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.12)))
            }
            .disabled(auth.busy)
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.black.opacity(0.1)).frame(height: 1)
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
        }
    }
}

// MARK: - Hero photo mosaic

/// Diagonal photo mosaic: an oversized uniform grid rotated so the white gaps
/// run on a diagonal, then clipped to the hero frame so it always fills the area.
struct HeroGrid: View {
    // ONCF Al Boraq train as the dominant image, with real station photos around it.
    private let names = ["TrainHero", "TangierStation", "TrainHero", "CasaStation",
                         "RabatStation", "TrainHero", "Station", "TrainInterior"]
    private let cols = 4
    private let rows = 7
    private let tile: CGFloat = 132
    private let gap: CGFloat = 8

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(0..<cols, id: \.self) { c in
                        let idx = (r * cols + c + r) % names.count   // shift per row so columns vary
                        Image(names[idx])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: tile, height: tile)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
        .rotationEffect(.degrees(-15))
        .scaleEffect(1.55)
        .accessibilityHidden(true)
    }
}

// MARK: - Pill button styles (clean, image-led aesthetic)

/// Full-width near-black pill (primary).
struct DarkPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 17)
            .background(Brand.ink, in: Capsule())
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Full-width white pill with hairline border (secondary).
struct LightPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Brand.label)
            .padding(.vertical, 16)
            .background(Brand.field, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.12)))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Google "G" in the four brand colours.
struct GoogleGlyph: View {
    var size: CGFloat = 18
    var body: some View {
        Text("G")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: [Color(hex: 0x4285F4), Color(hex: 0x34A853),
                                        Color(hex: 0xFBBC05), Color(hex: 0xEA4335)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: size + 6, height: size + 6)
            .accessibilityHidden(true)
    }
}

#Preview { AuthView().environmentObject(AuthViewModel()) }
