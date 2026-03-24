import Foundation

struct ConfigProviderAuthRecord: Equatable {
    let providerID: String
    let apiKey: String
    let isDisabled: Bool
}

enum ConfigComposer {
    static let uiMetadataKeys: Set<String> = ["display-name", "help-text", "icon-system"]
    
    static func composeAdditiveBaseConfig(bundledRoot: [String: Any], userRoot: [String: Any]?) -> [String: Any] {
        guard let userRoot else {
            return bundledRoot
        }
        return mergeDictionary(bundledRoot, overlaidWith: userRoot)
    }
    
    static func parseCustomProviders(
        from root: [String: Any],
        reservedProviderIDs: Set<String>
    ) -> [CustomProviderDefinition] {
        stringKeyedDictionaryArray(root["openai-compatibility"])
            .compactMap { entry in
                guard let providerID = entry["name"] as? String,
                      !providerID.isEmpty,
                      !reservedProviderIDs.contains(providerID) else {
                    return nil
                }
                
                let modelAliases = stringKeyedDictionaryArray(entry["models"])
                    .compactMap { model in
                        (model["alias"] as? String) ?? (model["name"] as? String)
                    }
                return CustomProviderDefinition(
                    id: providerID,
                    title: (entry["display-name"] as? String) ?? CustomProviderDefinition.defaultTitle(for: providerID),
                    baseURL: entry["base-url"] as? String ?? "",
                    helpText: entry["help-text"] as? String,
                    iconSystemName: entry["icon-system"] as? String,
                    modelAliases: modelAliases,
                    inlineKeyCount: apiKeyEntries(from: entry).count
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    static func composeRuntimeConfig(
        baseRoot: [String: Any],
        reservedCustomProviderKeys: Set<String>,
        disabledCustomProviderIDs: Set<String>,
        disabledOAuthProviderKeys: [String],
        zaiAPIKeys: [String],
        customProviderAuthRecords: [ConfigProviderAuthRecord],
        includeManagedZAIProvider: Bool,
        managedZAIProviderName: String = "zai"
    ) -> [String: Any] {
        var mergedRoot = baseRoot
        
        let oauthExcludedModels = buildOAuthExcludedModels(
            from: mergedRoot["oauth-excluded-models"],
            disabledOAuthProviderKeys: disabledOAuthProviderKeys
        )
        if let oauthExcludedModels {
            mergedRoot["oauth-excluded-models"] = oauthExcludedModels
        } else {
            mergedRoot.removeValue(forKey: "oauth-excluded-models")
        }
        
        let managedCustomProviderIDs = Set(
            parseCustomProviders(from: baseRoot, reservedProviderIDs: reservedCustomProviderKeys).map(\.id)
        )
        let authEntriesByProviderID = Dictionary(
            grouping: customProviderAuthRecords.filter { !$0.isDisabled },
            by: \.providerID
        ).mapValues { records in
            records.map { ["api-key": $0.apiKey] }
        }
        
        var mergedOpenAICompatibility: [[String: Any]] = []
        for entry in stringKeyedDictionaryArray(mergedRoot["openai-compatibility"]) {
            guard let providerName = entry["name"] as? String, !providerName.isEmpty else {
                continue
            }
            if providerName == managedZAIProviderName {
                continue
            }
            
            var sanitizedEntry = stripCustomProviderUIMetadata(from: entry)
            if managedCustomProviderIDs.contains(providerName) {
                if disabledCustomProviderIDs.contains(providerName) {
                    continue
                }
                
                let inlineEntries = apiKeyEntries(from: entry)
                let authEntries = authEntriesByProviderID[providerName] ?? []
                let effectiveEntries = deduplicatedAPIKeyEntries(inlineEntries + authEntries)
                guard !effectiveEntries.isEmpty else {
                    continue
                }
                sanitizedEntry["api-key-entries"] = effectiveEntries
            }
            
            mergedOpenAICompatibility.append(sanitizedEntry)
        }
        
        if includeManagedZAIProvider && !zaiAPIKeys.isEmpty {
            mergedOpenAICompatibility.append(makeZAIProviderEntry(apiKeys: zaiAPIKeys))
        }
        
        if mergedOpenAICompatibility.isEmpty {
            mergedRoot.removeValue(forKey: "openai-compatibility")
        } else {
            mergedRoot["openai-compatibility"] = mergedOpenAICompatibility
        }
        
        return mergedRoot
    }
    
    static func stringKeyedDictionary(_ value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let dictionary = value as? [AnyHashable: Any] {
            var stringDictionary: [String: Any] = [:]
            for (key, nestedValue) in dictionary {
                guard let stringKey = key as? String else {
                    continue
                }
                stringDictionary[stringKey] = nestedValue
            }
            return stringDictionary
        }
        return nil
    }
    
    static func stringKeyedDictionaryArray(_ value: Any?) -> [[String: Any]] {
        guard let array = value as? [Any] else {
            return []
        }
        return array.compactMap { stringKeyedDictionary($0) }
    }

    static func stringArray(_ value: Any?) -> [String] {
        if let array = value as? [String] {
            return array
        }
        if let array = value as? [Any] {
            return array.compactMap { $0 as? String }
        }
        return []
    }

    static func isOAuthProviderWildcardExcluded(_ oauthProviderKey: String, in root: [String: Any]) -> Bool {
        let exclusions = stringKeyedDictionary(root["oauth-excluded-models"] ?? [:]) ?? [:]
        return stringArray(exclusions[oauthProviderKey]).contains("*")
    }
    
    private static func mergeDictionary(_ base: [String: Any], overlaidWith overlay: [String: Any]) -> [String: Any] {
        var merged = base
        
        for (key, overlayValue) in overlay {
            if key == "openai-compatibility" {
                let overlayEntries = stringKeyedDictionaryArray(overlayValue)
                if overlayEntries.isEmpty {
                    merged[key] = overlayValue
                } else {
                    let baseEntries = stringKeyedDictionaryArray(merged[key])
                    merged[key] = mergeNamedEntries(base: baseEntries, overlay: overlayEntries)
                }
                continue
            }
            
            if let overlayDictionary = stringKeyedDictionary(overlayValue),
               let baseDictionary = merged[key].flatMap(stringKeyedDictionary) {
                merged[key] = mergeDictionary(baseDictionary, overlaidWith: overlayDictionary)
            } else {
                merged[key] = overlayValue
            }
        }
        
        return merged
    }
    
    private static func mergeNamedEntries(base: [[String: Any]], overlay: [[String: Any]]) -> [[String: Any]] {
        var mergedEntries = base
        var indexByName: [String: Int] = [:]
        
        for (index, entry) in base.enumerated() {
            if let name = entry["name"] as? String, !name.isEmpty {
                indexByName[name] = index
            }
        }
        
        for overlayEntry in overlay {
            guard let name = overlayEntry["name"] as? String, !name.isEmpty else {
                mergedEntries.append(overlayEntry)
                continue
            }
            
            if let existingIndex = indexByName[name] {
                let existingEntry = mergedEntries[existingIndex]
                mergedEntries[existingIndex] = mergeDictionary(existingEntry, overlaidWith: overlayEntry)
            } else {
                indexByName[name] = mergedEntries.count
                mergedEntries.append(overlayEntry)
            }
        }
        
        return mergedEntries
    }
    
    private static func apiKeyEntries(from entry: [String: Any]) -> [[String: String]] {
        stringKeyedDictionaryArray(entry["api-key-entries"]).compactMap { keyEntry in
            guard let apiKey = keyEntry["api-key"] as? String else {
                return nil
            }
            return ["api-key": apiKey]
        }
    }
    
    private static func deduplicatedAPIKeyEntries(_ entries: [[String: String]]) -> [[String: String]] {
        var seen: Set<String> = []
        return entries.filter { entry in
            guard let apiKey = entry["api-key"] else {
                return false
            }
            if seen.contains(apiKey) {
                return false
            }
            seen.insert(apiKey)
            return true
        }
    }
    
    private static func stripCustomProviderUIMetadata(from entry: [String: Any]) -> [String: Any] {
        var sanitized = entry
        for key in uiMetadataKeys {
            sanitized.removeValue(forKey: key)
        }
        return sanitized
    }
    
    private static func buildOAuthExcludedModels(
        from value: Any?,
        disabledOAuthProviderKeys: [String]
    ) -> [String: Any]? {
        var merged = stringKeyedDictionary(value ?? [:]) ?? [:]
        for providerKey in disabledOAuthProviderKeys.sorted() {
            merged[providerKey] = ["*"]
        }
        return merged.isEmpty ? nil : merged
    }
    
    private static func makeZAIProviderEntry(apiKeys: [String]) -> [String: Any] {
        [
            "name": "zai",
            "base-url": "https://api.z.ai/api/coding/paas/v4",
            "api-key-entries": apiKeys.map { ["api-key": $0] },
            "models": [
                ["name": "glm-4.7", "alias": "glm-4.7"],
                ["name": "glm-4-plus", "alias": "glm-4-plus"],
                ["name": "glm-4-air", "alias": "glm-4-air"],
                ["name": "glm-4-flash", "alias": "glm-4-flash"]
            ]
        ]
    }
}
