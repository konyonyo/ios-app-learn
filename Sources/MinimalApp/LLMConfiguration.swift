import Foundation
import Security

struct LLMConfiguration {
    var endpoint: String
    var model: String
    var organizationID: String
    var reasoningEffort: String
    var apiKey: String

    static let `default` = LLMConfiguration(
        endpoint: "https://api.openai.com/v1/chat/completions",
        model: "gpt-4o-2024-11-20",
        organizationID: "",
        reasoningEffort: "",
        apiKey: ""
    )

    var isConfigured: Bool {
        URL(string: endpoint) != nil && !model.isEmpty && !apiKey.isEmpty
    }

    static func load() -> LLMConfiguration {
        let defaults = UserDefaults.standard
        let defaultConfiguration = LLMConfiguration.default

        return LLMConfiguration(
            endpoint: defaults.string(forKey: "llm.endpoint") ?? defaultConfiguration.endpoint,
            model: defaults.string(forKey: "llm.model") ?? defaultConfiguration.model,
            organizationID: defaults.string(forKey: "llm.organizationID") ?? "",
            reasoningEffort: defaults.string(forKey: "llm.reasoningEffort") ?? "",
            apiKey: (try? KeychainStore.read(key: "llm.apiKey")) ?? ""
        )
    }

    func save() throws {
        UserDefaults.standard.set(endpoint, forKey: "llm.endpoint")
        UserDefaults.standard.set(model, forKey: "llm.model")
        UserDefaults.standard.set(organizationID, forKey: "llm.organizationID")
        UserDefaults.standard.set(reasoningEffort, forKey: "llm.reasoningEffort")
        try KeychainStore.save(apiKey, key: "llm.apiKey")
    }
}

enum KeychainStore {
    static func save(_ value: String, key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let attributes: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                attributes as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainError(status: updateStatus)
            }
        } else if status == errSecItemNotFound {
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError(status: addStatus)
            }
        } else {
            throw KeychainError(status: status)
        }
    }

    static func read(key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError(status: errSecDecode)
        }
        return value
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "Keychain error: \(status)"
    }
}
