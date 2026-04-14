import Foundation
import AuthenticationServices

@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var userEmail: String?

    private let tokenKey = "cf_access_token"
    private let emailKey = "cf_user_email"

    override init() {
        super.init()
        // Restore saved token
        if let token = KeychainHelper.load(key: tokenKey) {
            APIClient.shared.setAuthToken(token)
            userEmail = UserDefaults.standard.string(forKey: emailKey)
            isAuthenticated = true
        }
    }

    // Demo token for App Store review — pre-authenticated account
    // that bypasses the Cloudflare OTP flow. Expires May 14, 2026.
    static let demoEmail = "demo@storycharts.com"
    private static let demoToken = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjdmMmFhNGQ1MWZkNjU1MTZmNzE1MjEzMzQwYmE1MzFiMmUwZWUyMDJmYjJiZDM3MmUxYTUwNDc2YWQ0NWJkOTcifQ.eyJhdWQiOlsiNmQ0MDNiNjVhYmU4MTgzYTc4YTc3NWJmNWEzNTIyM2I3NGM5NmM2ZDdlOTA1MDEzNTA1MTNiZDExZmM2N2QwMCJdLCJlbWFpbCI6ImphbWVzZGFpQGxqcmVzb3VyY2VzLmNvbSIsImV4cCI6MTc3ODc3NDM1OSwiaWF0IjoxNzc2MTQ2MzU5LCJuYmYiOjE3NzYxNDYzNTksImlzcyI6Imh0dHBzOi8vc3RvcnljaGFydHMuY2xvdWRmbGFyZWFjY2Vzcy5jb20iLCJ0eXBlIjoiYXBwIiwiaWRlbnRpdHlfbm9uY2UiOiJIOGxYclpkb2lidXNyb0gxIiwic3ViIjoiZmRhNWI2ZjgtZGU5NS01ZTVlLWE0ZWQtZDQ1NmUwNTY5MmQyIiwiY291bnRyeSI6IlVTIiwicG9saWN5X2lkIjoiYjFlNzAzMTItOTA0Mi00ZjEwLTllMzItOTM1M2EzNWRkMmI5In0.KjaB7i062Tci-FoqKsYxtXlj2Qy6YEw9hC3oWXxkslIvk0z4HMO2D4_nnqoudu8x5i4AYG_UYhgBU3jqag1sE9GZaQyrgfH-QGxVb9y0Tko24h2ODW8NsazigRk-fJ04ocENrjXMbYS470OsjduxrLgf6IaGftE0ZXJRy42jzAhgKXD7ApRFIjE_kUBTvhCpvlXdaT4disKBzWSzguFMnKJG0d8guu__gTrMia1X31-FsB_TyimGvYxkEd7Ya-wNtEriSAJtDKnjy4ozshTem9vY0c_JvRE6pqaHH5VwO5uvYAZkugB1BdaEJYr531FUGyqJx3zIMQqsrtu9mc2E9A"

    func signIn() async throws {
        let token = try await performWebAuth()
        // Save token
        KeychainHelper.save(key: tokenKey, value: token)
        APIClient.shared.setAuthToken(token)

        // Decode email from JWT
        if let email = decodeEmailFromJWT(token) {
            userEmail = email
            UserDefaults.standard.set(email, forKey: emailKey)
        }
        isAuthenticated = true
    }

    /// Sign in with the pre-authenticated demo account (for App Store review).
    func signInAsDemo() {
        KeychainHelper.save(key: tokenKey, value: Self.demoToken)
        APIClient.shared.setAuthToken(Self.demoToken)
        userEmail = Self.demoEmail
        UserDefaults.standard.set(Self.demoEmail, forKey: emailKey)
        isAuthenticated = true
    }

    func signOut() {
        KeychainHelper.delete(key: tokenKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        APIClient.shared.setAuthToken(nil)
        userEmail = nil
        isAuthenticated = false
    }

    /// Permanently delete the signed-in user's account. Deletes all stories
    /// (plots and scenes cascade) on the server, then signs out locally.
    /// Required by App Store guideline 5.1.1(v).
    func deleteAccount() async throws {
        try await APIClient.shared.deleteAccount()
        signOut()
    }

    private func performWebAuth() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let authURL = URL(string: "https://storycharts.com/api/auth/login?app=1")!
            let scheme = "storycharts"

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: AuthError.failed(error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
                      !token.isEmpty else {
                    continuation.resume(throwing: AuthError.failed("No token received"))
                    return
                }

                continuation.resume(returning: token)
            }

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            session.start()
        }
    }

    private func decodeEmailFromJWT(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String else { return nil }
        return email
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

enum AuthError: Error, LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Sign in was cancelled"
        case .failed(let msg): return msg
        }
    }
}

// Simple Keychain helper for token storage
enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
