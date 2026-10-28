import Foundation
import Combine
import Security

struct AuthUser: Decodable, Equatable {
    let id: String
    let email: String
}

struct AuthTokens: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

enum SessionTokenStore {
    private static let service = Bundle.main.bundleIdentifier ?? "LostAndFound"
    private static let account = "api-session-token"

    static func read() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw LocalAPIError(message: "Couldn't read the saved sign-in session from Keychain.")
        }
        return token
    }

    static func save(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw LocalAPIError(message: "Couldn't securely save the sign-in session.")
            }
        } else if status != errSecSuccess {
            throw LocalAPIError(message: "Couldn't securely save the sign-in session.")
        }
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published private(set) var isRestoring = true
    @Published var startupError: String?

    func restore() async {
        guard isRestoring else { return }
        do {
            guard let token = try SessionTokenStore.read() else {
                isRestoring = false
                return
            }
            user = try await LocalAPIClient.shared.currentUser(token: token)
        } catch {
            startupError = error.localizedDescription
        }
        isRestoring = false
    }

    func signIn(email: String, password: String) async throws {
        let tokens = try await LocalAPIClient.shared.signIn(email: email, password: password)
        try SessionTokenStore.save(tokens.accessToken)
        user = tokens.user
        startupError = nil
    }

    func signUp(email: String, password: String) async throws {
        let tokens = try await LocalAPIClient.shared.signUp(email: email, password: password)
        try SessionTokenStore.save(tokens.accessToken)
        user = tokens.user
        startupError = nil
    }

    func signOut() async {
        if let token = try? SessionTokenStore.read() {
            try? await LocalAPIClient.shared.signOut(token: token)
        }
        SessionTokenStore.delete()
        user = nil
    }
}
