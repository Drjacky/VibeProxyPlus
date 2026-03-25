import Foundation

struct CustomProviderCredentialRecord: Equatable {
    let providerID: String
    let apiKey: String
    let label: String
    let filePath: URL
    let isDisabled: Bool
}

struct CustomProviderCredentialLoadIssue: Equatable {
    let filePath: URL
    let message: String
}

struct CustomProviderCredentialLoadResult: Equatable {
    let records: [CustomProviderCredentialRecord]
    let issues: [CustomProviderCredentialLoadIssue]
}

enum CustomProviderCredentialStoreError: LocalizedError {
    case failedToCreateDirectory(String)
    case failedToSerializeCredential(String)
    case failedToWriteCredential(String)
    case failedToReadCredential(String)
    case invalidCredentialJSON(String)
    case malformedCredential(String)
    case failedToDeleteCredential(String)

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory(let message),
             .failedToSerializeCredential(let message),
             .failedToWriteCredential(let message),
             .failedToReadCredential(let message),
             .invalidCredentialJSON(let message),
             .malformedCredential(let message),
             .failedToDeleteCredential(let message):
            return message
        }
    }
}

final class CustomProviderCredentialStore {
    static let authType = "openai-compat"

    private let directoryURL: URL
    private let fileManager: FileManager
    private let queue: DispatchQueue

    init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        queueLabel: String = "io.automaze.vibeproxy.custom-provider-credentials"
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.queue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    }

    func save(
        providerID: String,
        apiKey: String,
        label: String? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> URL {
        try queue.sync {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                throw CustomProviderCredentialStoreError.failedToCreateDirectory(
                    "Failed to create auth directory at \(directoryURL.path): \(error.localizedDescription)"
                )
            }

            let filename = "openai-compat-\(sanitizeFilenameComponent(providerID))-\(UUID().uuidString.prefix(8)).json"
            let filePath = directoryURL.appendingPathComponent(filename)
            let authData: [String: Any] = [
                "type": Self.authType,
                "provider": providerID,
                "label": label ?? maskAPIKey(apiKey),
                "api_key": apiKey,
                "created": createdAt
            ]

            let jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: authData, options: .prettyPrinted)
            } catch {
                throw CustomProviderCredentialStoreError.failedToSerializeCredential(
                    "Failed to serialize credential for \(providerID): \(error.localizedDescription)"
                )
            }

            do {
                try jsonData.write(to: filePath, options: Data.WritingOptions.atomic)
                try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: filePath.path)
            } catch {
                throw CustomProviderCredentialStoreError.failedToWriteCredential(
                    "Failed to write credential file at \(filePath.path): \(error.localizedDescription)"
                )
            }

            return filePath
        }
    }

    func delete(filePath: URL) throws {
        try queue.sync {
            do {
                try fileManager.removeItem(at: filePath)
            } catch {
                throw CustomProviderCredentialStoreError.failedToDeleteCredential(
                    "Failed to delete credential file at \(filePath.path): \(error.localizedDescription)"
                )
            }
        }
    }

    func toggleDisabled(filePath: URL) throws -> CustomProviderCredentialRecord {
        try queue.sync {
            let data: Data
            do {
                data = try Data(contentsOf: filePath)
            } catch {
                throw CustomProviderCredentialStoreError.failedToReadCredential(
                    "Failed to read credential file at \(filePath.path): \(error.localizedDescription)"
                )
            }

            let jsonObject: Any
            do {
                jsonObject = try JSONSerialization.jsonObject(with: data)
            } catch {
                throw CustomProviderCredentialStoreError.invalidCredentialJSON(
                    "Credential file at \(filePath.path) contains invalid JSON: \(error.localizedDescription)"
                )
            }

            guard var json = ConfigComposer.stringKeyedDictionary(jsonObject) else {
                throw CustomProviderCredentialStoreError.malformedCredential(
                    "Credential file at \(filePath.path) must contain a JSON object."
                )
            }

            let currentRecord = try record(from: json, filePath: filePath)
            json["disabled"] = !currentRecord.isDisabled

            let updatedData: Data
            do {
                updatedData = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            } catch {
                throw CustomProviderCredentialStoreError.failedToSerializeCredential(
                    "Failed to serialize updated credential for \(currentRecord.providerID): \(error.localizedDescription)"
                )
            }

            do {
                try updatedData.write(to: filePath, options: Data.WritingOptions.atomic)
                try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: filePath.path)
            } catch {
                throw CustomProviderCredentialStoreError.failedToWriteCredential(
                    "Failed to write credential file at \(filePath.path): \(error.localizedDescription)"
                )
            }

            var updatedJSON = json
            updatedJSON["disabled"] = !(currentRecord.isDisabled)
            return try record(from: updatedJSON, filePath: filePath)
        }
    }

    func loadAll() -> CustomProviderCredentialLoadResult {
        queue.sync {
            guard let files = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            ) else {
                return CustomProviderCredentialLoadResult(records: [], issues: [])
            }

            var records: [CustomProviderCredentialRecord] = []
            var issues: [CustomProviderCredentialLoadIssue] = []

            for file in files where isManagedCredentialFile(file) {
                do {
                    records.append(try loadRecord(at: file))
                } catch let error as CustomProviderCredentialStoreError {
                    issues.append(
                        CustomProviderCredentialLoadIssue(
                            filePath: file,
                            message: error.localizedDescription
                        )
                    )
                } catch {
                    issues.append(
                        CustomProviderCredentialLoadIssue(
                            filePath: file,
                            message: "Unexpected error while loading \(file.path): \(error.localizedDescription)"
                        )
                    )
                }
            }

            return CustomProviderCredentialLoadResult(records: records, issues: issues)
        }
    }

    private func loadRecord(at filePath: URL) throws -> CustomProviderCredentialRecord {
        let data: Data
        do {
            data = try Data(contentsOf: filePath)
        } catch {
            throw CustomProviderCredentialStoreError.failedToReadCredential(
                "Failed to read credential file at \(filePath.path): \(error.localizedDescription)"
            )
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CustomProviderCredentialStoreError.invalidCredentialJSON(
                "Credential file at \(filePath.path) contains invalid JSON: \(error.localizedDescription)"
            )
        }

        guard let json = ConfigComposer.stringKeyedDictionary(jsonObject) else {
            throw CustomProviderCredentialStoreError.malformedCredential(
                "Credential file at \(filePath.path) must contain a JSON object."
            )
        }

        return try record(from: json, filePath: filePath)
    }

    private func record(from json: [String: Any], filePath: URL) throws -> CustomProviderCredentialRecord {
        guard (json["type"] as? String) == Self.authType else {
            throw CustomProviderCredentialStoreError.malformedCredential(
                "Credential file at \(filePath.path) has an unexpected type."
            )
        }
        guard let providerID = json["provider"] as? String, !providerID.isEmpty else {
            throw CustomProviderCredentialStoreError.malformedCredential(
                "Credential file at \(filePath.path) is missing a provider."
            )
        }
        guard let apiKey = json["api_key"] as? String, !apiKey.isEmpty else {
            throw CustomProviderCredentialStoreError.malformedCredential(
                "Credential file at \(filePath.path) is missing an api_key."
            )
        }

        return CustomProviderCredentialRecord(
            providerID: providerID,
            apiKey: apiKey,
            label: (json["label"] as? String) ?? maskAPIKey(apiKey),
            filePath: filePath,
            isDisabled: json["disabled"] as? Bool ?? false
        )
    }

    private func isManagedCredentialFile(_ filePath: URL) -> Bool {
        filePath.pathExtension == "json" && filePath.lastPathComponent.hasPrefix("openai-compat-")
    }

    private func sanitizeFilenameComponent(_ value: String) -> String {
        let sanitized = value.replacingOccurrences(
            of: "[^A-Za-z0-9._-]+",
            with: "-",
            options: .regularExpression
        )
        return sanitized.isEmpty ? "provider" : sanitized
    }

    private func maskAPIKey(_ apiKey: String) -> String {
        guard apiKey.count > 12 else {
            return apiKey
        }
        return String(apiKey.prefix(8)) + "..." + String(apiKey.suffix(4))
    }
}
