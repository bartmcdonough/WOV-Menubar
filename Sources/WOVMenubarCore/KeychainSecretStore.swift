import Foundation
import Security

public protocol SecretStoring: Sendable {
    func loadSecret(account: String) throws -> String?
    func saveSecret(_ secret: String, account: String) throws
    func deleteSecret(account: String) throws
}

public enum KeychainSecretError: Error, LocalizedError {
    case encodingFailed
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Secret could not be encoded for Keychain storage."
        case .unexpectedStatus(let status):
            "Keychain operation failed with status \(status)."
        }
    }
}

public final class KeychainSecretStore: SecretStoring, @unchecked Sendable {
    private let service: String

    public init(service: String = "com.walkonvalley.WOVMenubar") {
        self.service = service
    }

    public func loadSecret(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainSecretError.unexpectedStatus(status)
        }
        guard let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func saveSecret(_ secret: String, account: String) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainSecretError.encodingFailed
        }

        try deleteSecret(account: account)

        var attributes = baseQuery(account: account)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainSecretError.unexpectedStatus(status)
        }
    }

    public func deleteSecret(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretError.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public final class InMemorySecretStore: SecretStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var secrets: [String: String]

    public init(secrets: [String: String] = [:]) {
        self.secrets = secrets
    }

    public func loadSecret(account: String) throws -> String? {
        lock.withLock { secrets[account] }
    }

    public func saveSecret(_ secret: String, account: String) throws {
        lock.withLock {
            secrets[account] = secret
        }
    }

    public func deleteSecret(account: String) throws {
        _ = lock.withLock {
            secrets.removeValue(forKey: account)
        }
    }
}
