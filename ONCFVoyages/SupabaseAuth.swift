//
//  SupabaseAuth.swift
//  Real authentication backend (Supabase / GoTrue) over REST — no SDK.
//
//  Handles real sign-up confirmation e-mails, sign-in sessions, and password
//  reset via an e-mailed 6-digit code. Activates automatically once the project
//  URL + anon key are filled in below; otherwise the app uses the local demo.
//
//  ─────────────────────────────────────────────────────────────────────────
//  SETUP (done by the app owner — these are safe to embed; the anon key is a
//  public client key, NOT the secret service_role key):
//    1. supabase.com → create a project.
//    2. Authentication → Providers → Email: enable Email, turn ON "Confirm
//       email", and enable "Email OTP".
//    3. Project Settings → API → copy the Project URL and the anon public key
//       into the two constants below.
//  ─────────────────────────────────────────────────────────────────────────
//

import Foundation

enum SupabaseConfig {
    /// Supabase Project URL (derived from project ref rnkwzrsmumlmsmkxmkgz).
    static let url = "https://rnkwzrsmumlmsmkxmkgz.supabase.co"
    /// Publishable (client-safe) key — the replacement for the legacy anon key.
    static let anonKey = "sb_publishable__cd1ijEO8IjDBFMv8yyEtw_38A-siAH"

    static var isConfigured: Bool {
        !url.contains("YOUR_PROJECT") && !anonKey.contains("YOUR_SUPABASE_ANON_KEY")
    }
    static var base: URL { URL(string: url)! }
}

/// GoTrue REST client conforming to the same `AuthService` protocol as the
/// local demo, so the UI never changes.
final class SupabaseAuthService: AuthService {
    private let tokenKey = "sb_session_token"
    private let userKey  = "sb_user"

    private struct GoTrueUser: Decodable {
        let id: String
        let email: String?
        let user_metadata: [String: AnyCodable]?
    }
    private struct Session: Decodable {
        let access_token: String?
        let refresh_token: String?
        let user: GoTrueUser?
    }
    private struct GoTrueError: Decodable {
        let msg: String?; let error_description: String?; let message: String?
        var text: String? { msg ?? error_description ?? message }
    }

    // MARK: Requests

    private func request(_ path: String, method: String = "POST",
                         body: [String: Any]? = nil, bearer: String? = nil) async throws -> Data {
        // Build via string so query strings (e.g. token?grant_type=password) survive —
        // appendingPathComponent would percent-encode the "?" into the path → 404.
        guard let url = URL(string: SupabaseConfig.url + "/" + path) else { throw SupabaseError.server("URL invalide.") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(bearer ?? SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthError.invalidCredentials }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(GoTrueError.self, from: data))?.text
            throw SupabaseError.server(msg ?? "Erreur (\(http.statusCode)).")
        }
        return data
    }

    // MARK: Session persistence

    private func store(_ session: Session) -> User? {
        guard let gu = session.user, let email = gu.email else { return nil }
        let name = gu.user_metadata?["name"]?.stringValue ?? String(email.split(separator: "@").first ?? "Voyageur")
        let user = User(id: gu.id, name: name, email: email)
        if let token = session.access_token { Keychain.set(token, for: tokenKey) }
        if let data = try? JSONEncoder().encode(user) { UserDefaults.standard.set(data, forKey: userKey) }
        return user
    }

    func restore() -> User? {
        guard Keychain.get(tokenKey) != nil,
              let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else { return nil }
        return user
    }

    func signOut() {
        Keychain.delete(tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    // MARK: Auth

    func signUp(name: String, email: String, password: String) async throws -> User {
        // Tag the account with the chosen app language so verification e-mails
        // can be localised (the email template switches on {{ .Data.lang }}).
        let lang = UserDefaults.standard.string(forKey: "appLang") ?? "fr"
        let data = try await request("auth/v1/signup",
                                     body: ["email": email, "password": password,
                                            "data": ["name": name, "lang": lang]])
        let session = try? JSONDecoder().decode(Session.self, from: data)
        // Email-confirmation on → no session yet; tell the user to confirm.
        guard let session, session.access_token != nil, let user = store(session) else {
            throw SupabaseError.confirmationSent
        }
        return user
    }

    func signIn(email: String, password: String) async throws -> User {
        let data = try await request("auth/v1/token?grant_type=password",
                                     body: ["email": email, "password": password])
        let session = try JSONDecoder().decode(Session.self, from: data)
        guard let user = store(session) else { throw AuthError.invalidCredentials }
        return user
    }

    func confirmSignup(email: String, code: String) async throws -> User {
        let data = try await request("auth/v1/verify",
                                     body: ["email": email, "token": code.filter(\.isNumber), "type": "signup"])
        let session = try JSONDecoder().decode(Session.self, from: data)
        guard let user = store(session) else { throw AuthError.invalidCredentials }
        return user
    }

    func signInExternal(id: String, name: String, email: String) -> User {
        // The Google flow already verified the identity via ASWebAuthenticationSession;
        // persist it locally as the active session.
        let user = User(id: id, name: name.isEmpty ? "Voyageur" : name, email: email.lowercased())
        Keychain.set(id, for: tokenKey)
        if let data = try? JSONEncoder().encode(user) { UserDefaults.standard.set(data, forKey: userKey) }
        return user
    }

    func updateName(_ name: String) async throws -> User {
        guard let token = Keychain.get(tokenKey) else { throw AuthError.invalidCredentials }
        let data = try await request("auth/v1/user", method: "PUT", body: ["data": ["name": name]], bearer: token)
        let gu = try JSONDecoder().decode(GoTrueUser.self, from: data)
        let user = User(id: gu.id, name: name, email: gu.email ?? "")
        if let d = try? JSONEncoder().encode(user) { UserDefaults.standard.set(d, forKey: userKey) }
        return user
    }

    func changePassword(current: String, new: String) async throws {
        guard let token = Keychain.get(tokenKey) else { throw AuthError.invalidCredentials }
        guard new.count >= 6 else { throw AuthError.weakPassword }
        _ = try await request("auth/v1/user", method: "PUT", body: ["password": new], bearer: token)
    }

    func deleteAccount() async throws {
        // Self-deletion requires a privileged server endpoint (service_role / RPC),
        // which must not live in the app. Clear the local session here.
        signOut()
    }

    // MARK: Password reset (e-mailed OTP)

    func sendResetCode(email: String) async throws -> String? {
        // Password-recovery e-mail. Works for existing users only and returns
        // success silently if the e-mail isn't found (prevents account probing).
        _ = try await request("auth/v1/recover", body: ["email": email])
        return nil   // delivered by e-mail, nothing to show in-app
    }

    func confirmReset(email: String, code: String, newPassword: String) async throws {
        guard newPassword.count >= 6 else { throw AuthError.weakPassword }
        // 1) Verify the recovery code → obtain a session.
        let data = try await request("auth/v1/verify",
                                     body: ["email": email, "token": code.filter(\.isNumber), "type": "recovery"])
        let session = try JSONDecoder().decode(Session.self, from: data)
        guard let token = session.access_token else { throw AuthError.invalidCredentials }
        _ = store(session)
        // 2) Set the new password on the now-authenticated user.
        _ = try await request("auth/v1/user", method: "PUT", body: ["password": newPassword], bearer: token)
    }
}

enum SupabaseError: LocalizedError {
    case server(String), confirmationSent
    var errorDescription: String? {
        switch self {
        case .server(let m): return m
        case .confirmationSent: return "Compte créé. Vérifiez votre e-mail pour confirmer votre compte."
        }
    }
}

/// Minimal AnyCodable to read string values out of `user_metadata`.
struct AnyCodable: Decodable {
    let value: Any
    var stringValue: String? { value as? String }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = i }
        else if let b = try? c.decode(Bool.self) { value = b }
        else { value = "" }
    }
}
