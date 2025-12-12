import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedStatus(OSStatus)
    case unableToConvertToData
    case unableToConvertToString
    
    var localizedDescription: String {
        switch self {
        case .itemNotFound:
            return "Item not found in keychain"
        case .duplicateItem:
            return "Item already exists in keychain"
        case .invalidData:
            return "Invalid data format"
        case .unexpectedStatus(let status):
            return "Unexpected keychain status: \(status)"
        case .unableToConvertToData:
            return "Unable to convert value to data"
        case .unableToConvertToString:
            return "Unable to convert data to string"
        }
    }
}

class KeychainService {
    static let shared = KeychainService()
    
    private let serviceName = "SignatureManager"
    
    private init() {}
    
    // MARK: - Generic Keychain Operations
    
    func save<T: Codable>(_ value: T, for key: String) throws {
        let data = try JSONEncoder().encode(value)
        try saveData(data, for: key)
    }
    
    func load<T: Codable>(_ type: T.Type, for key: String) throws -> T {
        let data = try loadData(for: key)
        return try JSONDecoder().decode(type, from: data)
    }
    
    func saveString(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unableToConvertToData
        }
        try saveData(data, for: key)
    }
    
    func loadString(for key: String) throws -> String {
        let data = try loadData(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unableToConvertToString
        }
        return string
    }
    
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func exists(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Private Methods
    
    private func saveData(_ data: Data, for key: String) throws {
        // Check if item already exists
        if exists(for: key) {
            try updateData(data, for: key)
        } else {
            try addData(data, for: key)
        }
    }
    
    private func addData(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    private func updateData(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    private func loadData(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        
        return data
    }
}

// MARK: - Gmail Token Management

extension KeychainService {
    private enum GmailTokenKeys {
        static func accessToken(for email: String) -> String {
            return "gmail_access_token_\(email)"
        }
        
        static func refreshToken(for email: String) -> String {
            return "gmail_refresh_token_\(email)"
        }
        
        static func tokenExpiry(for email: String) -> String {
            return "gmail_token_expiry_\(email)"
        }
    }
    
    func saveGmailTokens(accessToken: String, refreshToken: String, expiresAt: Date, for email: String) throws {
        try saveString(accessToken, for: GmailTokenKeys.accessToken(for: email))
        try saveString(refreshToken, for: GmailTokenKeys.refreshToken(for: email))
        try save(expiresAt, for: GmailTokenKeys.tokenExpiry(for: email))
    }
    
    func loadGmailAccessToken(for email: String) throws -> String {
        return try loadString(for: GmailTokenKeys.accessToken(for: email))
    }
    
    func loadGmailRefreshToken(for email: String) throws -> String {
        return try loadString(for: GmailTokenKeys.refreshToken(for: email))
    }
    
    func loadGmailTokenExpiry(for email: String) throws -> Date {
        return try load(Date.self, for: GmailTokenKeys.tokenExpiry(for: email))
    }
    
    func isGmailTokenValid(for email: String) -> Bool {
        do {
            let expiryDate = try loadGmailTokenExpiry(for: email)
            return expiryDate > Date().addingTimeInterval(300) // 5 minute buffer
        } catch {
            return false
        }
    }
    
    func deleteGmailTokens(for email: String) throws {
        try? delete(for: GmailTokenKeys.accessToken(for: email))
        try? delete(for: GmailTokenKeys.refreshToken(for: email))
        try? delete(for: GmailTokenKeys.tokenExpiry(for: email))
    }
    
    func hasGmailTokens(for email: String) -> Bool {
        return exists(for: GmailTokenKeys.accessToken(for: email)) &&
               exists(for: GmailTokenKeys.refreshToken(for: email))
    }
}

// MARK: - OAuth State Management

extension KeychainService {
    private enum OAuthKeys {
        static let state = "oauth_state"
        static let codeVerifier = "oauth_code_verifier"
    }
    
    func saveOAuthState(_ state: String) throws {
        try saveString(state, for: OAuthKeys.state)
    }
    
    func loadOAuthState() throws -> String {
        return try loadString(for: OAuthKeys.state)
    }
    
    func deleteOAuthState() throws {
        try delete(for: OAuthKeys.state)
    }
    
    func saveCodeVerifier(_ codeVerifier: String) throws {
        try saveString(codeVerifier, for: OAuthKeys.codeVerifier)
    }
    
    func loadCodeVerifier() throws -> String {
        return try loadString(for: OAuthKeys.codeVerifier)
    }
    
    func deleteCodeVerifier() throws {
        try delete(for: OAuthKeys.codeVerifier)
    }
}