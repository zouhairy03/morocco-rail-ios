//
//  GoogleAuth.swift
//  Real "Sign in with Google" via OAuth 2.0 + PKCE.
//
//  Uses Apple's built-in ASWebAuthenticationSession — no GoogleSignIn SDK and no
//  Info.plist URL-scheme registration required (the session intercepts the
//  reversed-client-ID callback itself).
//
//  ─────────────────────────────────────────────────────────────────────────
//  SETUP (one-time, ~2 min, done by the app owner — I can't create credentials
//  in your Google account):
//    1. https://console.cloud.google.com  →  create / pick a project.
//    2. APIs & Services → Credentials → Create credentials → OAuth client ID.
//    3. Application type: iOS.  Bundle ID: com.oncf.voyages
//    4. Copy the generated Client ID and paste it into `GoogleConfig.clientID`.
//  That's it — the redirect scheme is derived automatically below.
//  ─────────────────────────────────────────────────────────────────────────
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

enum GoogleConfig {
    /// 🔧 PASTE YOUR iOS OAuth CLIENT ID HERE.
    /// Looks like: 1234567890-abcdefghijklmno.apps.googleusercontent.com
    static let clientID = "658616031803-ekofakft1af6ukvlcl17pb6vpdsq3b6b.apps.googleusercontent.com"

    /// False until a real client ID is pasted in (used to show a helpful message).
    static var isConfigured: Bool { !clientID.hasPrefix("YOUR_GOOGLE_IOS_CLIENT_ID") }

    /// Reversed-client-ID scheme Google uses as the OAuth redirect for iOS apps.
    static var reversedClientID: String {
        let suffix = ".apps.googleusercontent.com"
        let core = clientID.hasSuffix(suffix) ? String(clientID.dropLast(suffix.count)) : clientID
        return "com.googleusercontent.apps.\(core)"
    }
    static var redirectURI: String { "\(reversedClientID):/oauth2redirect" }
}

struct GoogleProfile { let sub: String; let email: String; let name: String }

enum GoogleAuthError: LocalizedError {
    case notConfigured, cancelled, badResponse, tokenExchange(String)
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Sign-In n'est pas encore configuré (Client ID manquant)."
        case .cancelled:      return "Connexion Google annulée."
        case .badResponse:    return "Réponse Google invalide."
        case .tokenExchange(let m): return "Échec de l'authentification Google : \(m)"
        }
    }
}

@MainActor
final class GoogleAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    /// Runs the full interactive Google flow and returns the verified profile.
    func signIn() async throws -> GoogleProfile {
        guard GoogleConfig.isConfigured else { throw GoogleAuthError.notConfigured }

        let verifier  = Self.codeVerifier()
        let challenge = Self.codeChallenge(verifier)
        let state     = UUID().uuidString

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id",             value: GoogleConfig.clientID),
            .init(name: "redirect_uri",          value: GoogleConfig.redirectURI),
            .init(name: "response_type",         value: "code"),
            .init(name: "scope",                 value: "openid email profile"),
            .init(name: "code_challenge",        value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state",                 value: state),
            .init(name: "prompt",                value: "select_account")
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(url: comps.url!,
                                               callbackURLScheme: GoogleConfig.reversedClientID) { url, error in
                if let url {
                    cont.resume(returning: url)
                } else if let err = error as? ASWebAuthenticationSessionError, err.code == .canceledLogin {
                    cont.resume(throwing: GoogleAuthError.cancelled)
                } else {
                    cont.resume(throwing: error ?? GoogleAuthError.badResponse)
                }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            self.session = s
            s.start()
        }

        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let code = items.first(where: { $0.name == "code" })?.value,
              items.first(where: { $0.name == "state" })?.value == state else {
            throw GoogleAuthError.badResponse
        }
        return try await exchange(code: code, verifier: verifier)
    }

    /// Exchange the authorization code for tokens (public client → no secret, PKCE).
    private func exchange(code: String, verifier: String) async throws -> GoogleProfile {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = [
            "code":          code,
            "client_id":     GoogleConfig.clientID,
            "redirect_uri":  GoogleConfig.redirectURI,
            "grant_type":    "authorization_code",
            "code_verifier": verifier
        ]
        req.httpBody = form.map { "\($0.key)=\(Self.formEncode($0.value))" }
            .joined(separator: "&").data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleAuthError.tokenExchange(String(data: data, encoding: .utf8) ?? "HTTP")
        }
        struct TokenResp: Decodable { let id_token: String }
        guard let token = try? JSONDecoder().decode(TokenResp.self, from: data) else {
            throw GoogleAuthError.badResponse
        }
        return try Self.decodeIDToken(token.id_token)
    }

    // MARK: ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    // MARK: PKCE + JWT helpers

    private static func codeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64url(Data(bytes))
    }
    private static func codeChallenge(_ verifier: String) -> String {
        base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
    }
    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    private static func formEncode(_ s: String) -> String {
        var cs = CharacterSet.urlQueryAllowed; cs.remove(charactersIn: "+&=")
        return s.addingPercentEncoding(withAllowedCharacters: cs) ?? s
    }
    private static func decodeIDToken(_ jwt: String) throws -> GoogleProfile {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { throw GoogleAuthError.badResponse }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+")
                                  .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String,
              let email = json["email"] as? String else { throw GoogleAuthError.badResponse }
        let name = (json["name"] as? String)
            ?? (email.split(separator: "@").first.map(String.init) ?? "Voyageur")
        return GoogleProfile(sub: sub, email: email, name: name)
    }
}
