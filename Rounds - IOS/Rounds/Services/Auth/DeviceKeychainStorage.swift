import Foundation
import Security
import Supabase

/// Where Supabase keeps the session: the Keychain, readable after the first unlock (so a token can
/// refresh in the background) but bound to this device, so it never travels in a backup or to a new
/// phone. The SDK's own storage uses plain `AfterFirstUnlock`, which does travel.
///
/// A session saved by the SDK's storage before this moves over on first read, so nobody is signed out.
struct DeviceKeychainStorage: AuthLocalStorage {
    private let service = "com.abdul.rounds.session"
    /// The SDK's default storage, read once per key to move an older session over.
    private let legacy = KeychainLocalStorage()

    func store(key: String, value: Data) throws {
        let query = baseQuery(key)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: value] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData] = value
            item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            try check(SecItemAdd(item as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    func retrieve(key: String) throws -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess { return result as? Data }
        guard status == errSecItemNotFound else { throw KeychainFailure(status: status) }
        guard let old = try? legacy.retrieve(key: key) else { return nil }
        try store(key: key, value: old)
        try? legacy.remove(key: key)
        return old
    }

    func remove(key: String) throws {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainFailure(status: status) }
        try? legacy.remove(key: key)
    }

    private func baseQuery(_ key: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: key]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw KeychainFailure(status: status) }
    }
}

/// A Keychain call failed with this status.
private struct KeychainFailure: Error {
    let status: OSStatus
}
