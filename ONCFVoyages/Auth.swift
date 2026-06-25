//
//  Auth.swift
//  Real account flow: signup / login, password hashing, Keychain session.
//
//  Backed locally on-device (UserDefaults for accounts, Keychain for the session
//  token). `AuthService` is a protocol, so a remote auth backend drops in without
//  touching the UI.
//

import Foundation
import Security
import CryptoKit

// MARK: - Model

struct User: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var email: String
}

enum AuthError: LocalizedError {
    case invalidCredentials, emailTaken, weakPassword, invalidEmail
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "E-mail ou mot de passe incorrect."
        case .emailTaken: return "Un compte existe déjà avec cet e-mail."
        case .weakPassword: return "Le mot de passe doit faire au moins 6 caractères."
        case .invalidEmail: return "Adresse e-mail invalide."
        }
    }
}

// MARK: - Keychain (session token)

enum Keychain {
    private static let service = "ma.oncf.voyages.session"

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var add = query; add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }
    static func get(_ key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func delete(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Service

protocol AuthService {
    func signUp(name: String, email: String, password: String) async throws -> User
    func signIn(email: String, password: String) async throws -> User
    /// Confirm a new account with the e-mailed verification code.
    func confirmSignup(email: String, code: String) async throws -> User
    /// Sign in with an external identity provider (Google, …) — no password.
    func signInExternal(id: String, name: String, email: String) -> User
    func signOut()
    func restore() -> User?
    func updateName(_ name: String) async throws -> User
    func changePassword(current: String, new: String) async throws
    func deleteAccount() async throws
    /// Start password reset. Returns a code to display when there is no real
    /// e-mail backend (demo); returns nil when the code is e-mailed (Supabase).
    func sendResetCode(email: String) async throws -> String?
    /// Verify the code and set the new password.
    func confirmReset(email: String, code: String, newPassword: String) async throws
}

/// On-device implementation. Swap for a remote one (same protocol) when a backend exists.
final class LocalAuthService: AuthService {
    private struct Account: Codable { let user: User; let hash: String }
    private let accountsKey = "oncf_accounts"
    private let tokenKey = "session_token"

    init() {
        // Seed a demo account on first run so the app is usable immediately.
        if accounts().isEmpty {
            let demo = User(id: UUID().uuidString, name: "Youssef Zouhair", email: "demo@oncf.ma")
            save(account: Account(user: demo, hash: Self.hash("voyages")))
        }
    }

    private static func hash(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func accounts() -> [Account] {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let a = try? JSONDecoder().decode([Account].self, from: data) else { return [] }
        return a
    }
    private func save(account: Account) {
        var all = accounts().filter { $0.user.email != account.user.email }
        all.append(account)
        if let data = try? JSONEncoder().encode(all) { UserDefaults.standard.set(data, forKey: accountsKey) }
    }
    private func valid(email: String) -> Bool {
        email.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }

    func signUp(name: String, email: String, password: String) async throws -> User {
        let email = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard valid(email: email) else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.weakPassword }
        guard !accounts().contains(where: { $0.user.email == email }) else { throw AuthError.emailTaken }
        try? await Task.sleep(nanoseconds: 400_000_000)
        let user = User(id: UUID().uuidString, name: name.trimmingCharacters(in: .whitespaces), email: email)
        save(account: Account(user: user, hash: Self.hash(password)))
        Keychain.set(user.id, for: tokenKey)
        return user
    }

    func signIn(email: String, password: String) async throws -> User {
        let email = email.lowercased().trimmingCharacters(in: .whitespaces)
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard let acc = accounts().first(where: { $0.user.email == email }),
              acc.hash == Self.hash(password) else { throw AuthError.invalidCredentials }
        Keychain.set(acc.user.id, for: tokenKey)
        return acc.user
    }

    func signInExternal(id: String, name: String, email: String) -> User {
        let email = email.lowercased().trimmingCharacters(in: .whitespaces)
        let user = User(id: id, name: name.isEmpty ? "Voyageur" : name, email: email)
        // Store a passwordless account so the session restores like any other.
        save(account: Account(user: user, hash: "external:google"))
        Keychain.set(user.id, for: tokenKey)
        return user
    }

    func signOut() { Keychain.delete(tokenKey) }

    func restore() -> User? {
        guard let id = Keychain.get(tokenKey) else { return nil }
        return accounts().first { $0.user.id == id }?.user
    }

    private func currentAccount() -> Account? {
        guard let id = Keychain.get(tokenKey) else { return nil }
        return accounts().first { $0.user.id == id }
    }

    func updateName(_ name: String) async throws -> User {
        guard let acc = currentAccount() else { throw AuthError.invalidCredentials }
        var u = acc.user; u.name = name.trimmingCharacters(in: .whitespaces)
        save(account: Account(user: u, hash: acc.hash))
        return u
    }

    func changePassword(current: String, new: String) async throws {
        guard let acc = currentAccount() else { throw AuthError.invalidCredentials }
        guard acc.hash == Self.hash(current) else { throw AuthError.invalidCredentials }
        guard new.count >= 6 else { throw AuthError.weakPassword }
        try? await Task.sleep(nanoseconds: 300_000_000)
        save(account: Account(user: acc.user, hash: Self.hash(new)))
    }

    func deleteAccount() async throws {
        guard let id = Keychain.get(tokenKey) else { return }
        let remaining = accounts().filter { $0.user.id != id }
        if let data = try? JSONEncoder().encode(remaining) { UserDefaults.standard.set(data, forKey: accountsKey) }
        Keychain.delete(tokenKey)
    }

    // Local accounts auto-confirm at sign-up, so this just returns the account.
    func confirmSignup(email: String, code: String) async throws -> User {
        let e = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard let acc = accounts().first(where: { $0.user.email == e }) else { throw AuthError.invalidCredentials }
        Keychain.set(acc.user.id, for: tokenKey)
        return acc.user
    }

    private var resetCodes: [String: String] = [:]

    func sendResetCode(email: String) async throws -> String? {
        let e = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard accounts().contains(where: { $0.user.email == e }) else { throw AuthError.invalidCredentials }
        let code = String(format: "%06d", Int.random(in: 0...999_999))
        resetCodes[e] = code
        return code   // shown in-app (no e-mail backend in the local/demo path)
    }

    func confirmReset(email: String, code: String, newPassword: String) async throws {
        let e = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard resetCodes[e] == code else { throw AuthError.invalidCredentials }
        guard newPassword.count >= 6 else { throw AuthError.weakPassword }
        guard let acc = accounts().first(where: { $0.user.email == e }) else { throw AuthError.invalidCredentials }
        save(account: Account(user: acc.user, hash: Self.hash(newPassword)))
        resetCodes[e] = nil
    }
}

// MARK: - View model

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var error: String?
    @Published var busy = false

    /// Real backend (Supabase) once configured, otherwise the on-device demo.
    private let service: AuthService = SupabaseConfig.isConfigured ? SupabaseAuthService() : LocalAuthService()
    private let google = GoogleAuth()

    /// Demo reset code to display in-app (nil when a real e-mail was sent).
    @Published var resetDemoCode: String?
    /// Set when sign-up needs an e-mailed code to confirm the account.
    @Published var pendingConfirmationEmail: String?

    init() { user = service.restore() }

    func signIn(email: String, password: String) async {
        busy = true; error = nil
        do { user = try await service.signIn(email: email, password: password) }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Erreur" }
        busy = false
    }
    func signUp(name: String, email: String, password: String) async {
        busy = true; error = nil
        do { user = try await service.signUp(name: name, email: email, password: password) }
        catch SupabaseError.confirmationSent {
            // Not an error — an e-mailed code is awaiting confirmation.
            pendingConfirmationEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Erreur" }
        busy = false
    }

    /// Confirm a pending sign-up with the e-mailed code.
    func confirmSignup(email: String, code: String) async -> Bool {
        busy = true; error = nil
        do {
            user = try await service.confirmSignup(email: email, code: code)
            pendingConfirmationEmail = nil; busy = false; return true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Erreur"; busy = false; return false
        }
    }
    func signInWithGoogle() async {
        busy = true; error = nil
        do {
            let p = try await google.signIn()
            user = service.signInExternal(id: "google:\(p.sub)", name: p.name, email: p.email)
        } catch GoogleAuthError.cancelled {
            // user backed out — no error banner
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Erreur"
        }
        busy = false
    }

    func signOut() { service.signOut(); user = nil }

    func updateName(_ name: String) async {
        busy = true; error = nil
        do { user = try await service.updateName(name) }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Erreur" }
        busy = false
    }
    func changePassword(current: String, new: String) async -> Bool {
        busy = true; error = nil
        do { try await service.changePassword(current: current, new: new); busy = false; return true }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Erreur"; busy = false; return false }
    }
    func deleteAccount() async {
        do { try await service.deleteAccount() } catch {}
        user = nil
    }

    /// Start password reset: e-mails (or, in demo, returns) a verification code.
    func sendResetCode(email: String) async -> Bool {
        busy = true; error = nil; resetDemoCode = nil
        do {
            resetDemoCode = try await service.sendResetCode(email: email)
            busy = false; return true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Erreur"; busy = false; return false
        }
    }

    /// Verify the code and set the new password.
    func confirmReset(email: String, code: String, newPassword: String) async -> Bool {
        busy = true; error = nil
        do { try await service.confirmReset(email: email, code: code, newPassword: newPassword); busy = false; return true }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Erreur"; busy = false; return false }
    }
}
