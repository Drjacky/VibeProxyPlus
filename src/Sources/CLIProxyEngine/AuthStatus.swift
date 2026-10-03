import Foundation

enum ServiceType: String, CaseIterable {
    case claude
    case codex
    case copilot = "github-copilot"
    case gemini
    case kimi
    case qwen
    case antigravity
    case zai
    case cursor
    
    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .copilot: return "GitHub Copilot"
        case .gemini: return "Gemini"
        case .kimi: return "Kimi"
        case .qwen: return "Qwen"
        case .antigravity: return "Antigravity"
        case .zai: return "Z.AI GLM"
        case .cursor: return "Cursor"
        }
    }
}

/// Global cloak mode applied to all Claude OAuth accounts.
///
/// Written into each Claude auth JSON file as the string field `cloak_mode`, which the
/// CLIProxyAPIPlus binary (>= 7.2.62-0) reads from the auth-file metadata:
/// - `auto`: cloak only when the client is not Claude Code (based on User-Agent)
/// - `always`: always apply cloaking regardless of client
/// - `never`: never apply cloaking
enum CloakMode: String, CaseIterable {
    case auto
    case always
    case never

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .always: return "Always"
        case .never: return "Never"
        }
    }
}

/// Represents a single authenticated account
struct AuthAccount: Identifiable, Equatable {
    let id: String  // filename
    let email: String?
    let login: String?  // for Copilot
    let type: ServiceType
    let expired: Date?
    let filePath: URL
    let isDisabled: Bool
    
    var isExpired: Bool {
        guard let expired = expired else { return false }
        return expired < Date()
    }
    
    var displayName: String {
        if let email = email, !email.isEmpty {
            return email
        }
        if let login = login, !login.isEmpty {
            return login
        }
        return id
    }
    
    static func == (lhs: AuthAccount, rhs: AuthAccount) -> Bool {
        lhs.id == rhs.id
    }
}

/// Tracks all accounts for a service type
struct ServiceAccounts {
    var type: ServiceType
    var accounts: [AuthAccount] = []
    
    var hasAccounts: Bool { !accounts.isEmpty }
    var activeCount: Int { accounts.filter { !$0.isExpired }.count }
    var expiredCount: Int { accounts.filter { $0.isExpired }.count }
}

class AuthManager: ObservableObject {
    @Published var serviceAccounts: [ServiceType: ServiceAccounts] = [:]
    
    private static let dateFormatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return [withFractional, standard]
    }()
    
    init() {
        // Initialize empty accounts for all service types
        for type in ServiceType.allCases {
            serviceAccounts[type] = ServiceAccounts(type: type)
        }
    }
    
    func accounts(for type: ServiceType) -> [AuthAccount] {
        serviceAccounts[type]?.accounts ?? []
    }
    
    func hasAccounts(for type: ServiceType) -> Bool {
        serviceAccounts[type]?.hasAccounts ?? false
    }
    
    private static func parseDate(_ value: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    func checkAuthStatus() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        
        // Build new accounts dictionary
        var newAccounts: [ServiceType: [AuthAccount]] = [:]
        for type in ServiceType.allCases {
            newAccounts[type] = []
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
            NSLog("[AuthStatus] Scanning %d files in auth directory", files.count)
            
            for file in files where file.pathExtension == "json" {
                NSLog("[AuthStatus] Checking file: %@", file.lastPathComponent)
                guard let data = try? Data(contentsOf: file),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String,
                      let serviceType = ServiceType(rawValue: type.lowercased()) else {
                    continue
                }
                
                NSLog("[AuthStatus] Found type '%@' in %@", type, file.lastPathComponent)
                
                let email = json["email"] as? String
                let login = json["login"] as? String
                var expiredDate: Date?
                
                if let expiredStr = json["expired"] as? String {
                    expiredDate = Self.parseDate(expiredStr)
                } else if let expiresAt = json["expires_at"] as? String {
                    expiredDate = Self.parseDate(expiresAt)
                }
                
                let isDisabled = json["disabled"] as? Bool ?? false
                
                let account = AuthAccount(
                    id: file.lastPathComponent,
                    email: email,
                    login: login,
                    type: serviceType,
                    expired: expiredDate,
                    filePath: file,
                    isDisabled: isDisabled
                )
                
                newAccounts[serviceType]?.append(account)
                NSLog("[AuthStatus] Found %@ auth: %@", serviceType.displayName, account.displayName)
            }
            
            // Update on main thread
            DispatchQueue.main.async {
                for type in ServiceType.allCases {
                    self.serviceAccounts[type] = ServiceAccounts(
                        type: type,
                        accounts: newAccounts[type] ?? []
                    )
                }
            }
        } catch {
            NSLog("[AuthStatus] Error checking auth status: %@", error.localizedDescription)
            DispatchQueue.main.async {
                for type in ServiceType.allCases {
                    self.serviceAccounts[type] = ServiceAccounts(type: type)
                }
            }
        }
    }
    
    /// Toggle the disabled state of a specific account's auth file
    func toggleAccountDisabled(_ account: AuthAccount) -> Bool {
        do {
            let data = try Data(contentsOf: account.filePath)
            guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                NSLog("[AuthStatus] Failed to parse auth file as JSON: %@", account.filePath.path)
                return false
            }
            let currentlyDisabled = json["disabled"] as? Bool ?? false
            if !currentlyDisabled {
                let enabledCount = serviceAccounts[account.type]?.accounts.filter { !$0.isDisabled }.count ?? 0
                guard enabledCount > 1 else {
                    NSLog("[AuthStatus] Refusing to disable last enabled account for %@", account.type.rawValue)
                    return false
                }
            }
            json["disabled"] = !currentlyDisabled
            let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            try updatedData.write(to: account.filePath, options: .atomic)
            NSLog("[AuthStatus] Toggled disabled=%d for: %@", !currentlyDisabled, account.filePath.path)
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to toggle disabled state: %@", error.localizedDescription)
            return false
        }
    }
    
    /// Write global cloak settings into a single Claude account's auth JSON file.
    ///
    /// All four keys are stored as JSON strings because the CLIProxyAPIPlus binary only reads
    /// them from the auth-file metadata as strings (`cloak_mode`, `cloak_strict_mode`,
    /// `cloak_sensitive_words`, `cloak_cache_user_id`). Boolean/array values would be ignored.
    /// The caller is responsible for refreshing auth status once after applying to all accounts.
    @discardableResult
    func applyCloakSettings(
        to account: AuthAccount,
        mode: String,
        strictMode: Bool,
        sensitiveWords: String,
        cacheUserID: Bool
    ) -> Bool {
        do {
            let data = try Data(contentsOf: account.filePath)
            guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                NSLog("[AuthStatus] Failed to parse auth file as JSON: %@", account.filePath.path)
                return false
            }
            json["cloak_mode"] = mode
            json["cloak_strict_mode"] = strictMode ? "true" : "false"
            json["cloak_sensitive_words"] = sensitiveWords
            json["cloak_cache_user_id"] = cacheUserID ? "true" : "false"
            let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            try updatedData.write(to: account.filePath, options: .atomic)
            NSLog("[AuthStatus] Applied cloak_mode=%@ to: %@", mode, account.filePath.path)
            return true
        } catch {
            NSLog("[AuthStatus] Failed to apply cloak settings: %@", error.localizedDescription)
            return false
        }
    }

    /// Delete a specific account's auth file
    func deleteAccount(_ account: AuthAccount) -> Bool {
        do {
            try FileManager.default.removeItem(at: account.filePath)
            NSLog("[AuthStatus] Deleted auth file: %@", account.filePath.path)
            // Refresh status
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to delete auth file: %@", error.localizedDescription)
            return false
        }
    }
}
