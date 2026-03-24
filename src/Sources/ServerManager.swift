import Foundation
import Combine
import AppKit
import Yams

private struct RingBuffer<Element> {
    private var storage: [Element?]
    private var head = 0
    private var tail = 0
    private(set) var count = 0
    
    init(capacity: Int) {
        let safeCapacity = max(1, capacity)
        storage = Array(repeating: nil, count: safeCapacity)
    }
    
    mutating func append(_ element: Element) {
        let capacity = storage.count
        storage[tail] = element
        
        if count == capacity {
            head = (head + 1) % capacity
        } else {
            count += 1
        }
        
        tail = (tail + 1) % capacity
    }
    
    func elements() -> [Element] {
        let capacity = storage.count
        guard count > 0 else { return [] }
        
        var result: [Element] = []
        result.reserveCapacity(count)
        
        for index in 0..<count {
            let storageIndex = (head + index) % capacity
            if let value = storage[storageIndex] {
                result.append(value)
            }
        }
        
        return result
    }
}

class ServerManager: ObservableObject {
    private var process: Process?
    @Published private(set) var isRunning = false
    private(set) var port = 8317
    @Published private(set) var customProviders: [CustomProviderDefinition] = []
    @Published private(set) var customProviderCredentials: [String: [CustomProviderCredential]] = [:]
    @Published private(set) var configErrorMessage: String?

    /// Provider enabled states - when disabled, models are excluded via oauth-excluded-models
    @Published var enabledProviders: [String: Bool] = [:] {
        didSet {
            UserDefaults.standard.set(enabledProviders, forKey: "enabledProviders")
        }
    }

    /// Vercel AI Gateway configuration for Claude requests
    @Published var vercelGatewayEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(vercelGatewayEnabled, forKey: "vercelGatewayEnabled")
            onVercelConfigChanged?()
        }
    }
    @Published var vercelApiKey: String = "" {
        didSet {
            UserDefaults.standard.set(vercelApiKey, forKey: "vercelApiKey")
            onVercelConfigChanged?()
        }
    }
    var onVercelConfigChanged: (() -> Void)?

    /// Helper class to capture output text across closures
    private class OutputCapture {
        var text = ""
    }
    private var logBuffer: RingBuffer<String>
    private let maxLogLines = 1000
    private let processQueue = DispatchQueue(label: "io.automaze.vibeproxy.server-process", qos: .userInitiated)
    private var activeConfigPath = ""
    private var isRestartingForConfigUpdate = false
    private var hasPendingConfigUpdate = false
    
    private enum Timing {
        static let readinessCheckDelay: TimeInterval = 1.0
        static let gracefulTerminationTimeout: TimeInterval = 2.0
        static let terminationPollInterval: TimeInterval = 0.05
    }
    
    private enum CustomProviderConstants {
        static let authType = "openai-compat"
        static let userConfigFilename = "config.yaml"
        static let mergedConfigFilename = "merged-config.yaml"
        static let managedZAIProviderName = "zai"
    }
    
    private struct StoredCustomProviderAuthRecord {
        let providerID: String
        let apiKey: String
        let label: String
        let filePath: URL
        let isDisabled: Bool
    }

    private struct LoadedBaseConfig {
        let root: [String: Any]
        let isUserConfig: Bool
    }

    private struct ConfigResolutionFailure: Error {
        let message: String
    }
    
    var onLogUpdate: (([String]) -> Void)?

    /// OAuth provider keys used in config.yaml oauth-excluded-models
    static let oauthProviderKeys: [String: String] = [
        "claude": "claude",
        "codex": "codex",
        "gemini": "gemini-cli",
        "github-copilot": "github-copilot",
        "antigravity": "antigravity",
        "qwen": "qwen"
    ]
    static let reservedCustomProviderKeys = Set(oauthProviderKeys.keys).union([CustomProviderConstants.managedZAIProviderName])

    init() {
        logBuffer = RingBuffer(capacity: maxLogLines)
        if let saved = UserDefaults.standard.dictionary(forKey: "enabledProviders") as? [String: Bool] {
            enabledProviders = saved
        }
        vercelGatewayEnabled = UserDefaults.standard.bool(forKey: "vercelGatewayEnabled")
        vercelApiKey = UserDefaults.standard.string(forKey: "vercelApiKey") ?? ""
        reloadCustomProviders()
    }

    /// Check if a provider is enabled (defaults to true if not set)
    func isProviderEnabled(_ providerKey: String) -> Bool {
        let userEnabled = enabledProviders[providerKey] ?? true
        guard userEnabled else {
            return false
        }
        return providerConfigLockReason(providerKey) == nil
    }

    func providerConfigLockReason(_ providerKey: String) -> String? {
        guard let oauthProviderKey = Self.oauthProviderKeys[providerKey] else {
            return nil
        }
        guard case .success(let baseConfig) = loadBaseConfigRoot() else {
            return nil
        }
        guard ConfigComposer.isOAuthProviderWildcardExcluded(oauthProviderKey, in: baseConfig.root) else {
            return nil
        }
        return "Disabled by ~/.cli-proxy-api/config.yaml oauth-excluded-models. Remove the '*' exclusion for \(oauthProviderKey) to enable it here."
    }

    func isProviderToggleLocked(_ providerKey: String) -> Bool {
        providerConfigLockReason(providerKey) != nil
    }

    /// Set provider enabled state and regenerate config (hot reload - no restart needed)
    func setProviderEnabled(_ providerKey: String, enabled: Bool) {
        enabledProviders[providerKey] = enabled
        if enabled, let lockReason = providerConfigLockReason(providerKey) {
            addLog("⚠️ \(providerKey) remains disabled: \(lockReason)")
        } else {
            addLog(enabled ? "✓ Enabled provider: \(providerKey)" : "⚠️ Disabled provider: \(providerKey)")
        }
        reloadCustomProviders()
        applyConfigUpdate()
    }
    
    deinit {
        // Ensure cleanup on deallocation
        stop()
        killOrphanedProcesses()
    }
    
    func start(completion: @escaping (Bool) -> Void) {
        guard !isRunning else {
            completion(true)
            return
        }

        // Clean up any orphaned processes from previous crashes
        killOrphanedProcesses()

        // Use bundled binary from app bundle
        guard let resourcePath = Bundle.main.resourcePath else {
            addLog("❌ Error: Could not find resource path")
            completion(false)
            return
        }
        
        let bundledPath = (resourcePath as NSString).appendingPathComponent("cli-proxy-api-plus")
        guard FileManager.default.fileExists(atPath: bundledPath) else {
            addLog("❌ Error: cli-proxy-api-plus binary not found at \(bundledPath)")
            completion(false)
            return
        }
        
        // Use config path (merged with Z.AI if keys exist)
        let configPath = getConfigPath()
        guard !configPath.isEmpty && FileManager.default.fileExists(atPath: configPath) else {
            addLog("❌ Error: \(configErrorMessage ?? "Could not resolve active config path")")
            completion(false)
            return
        }
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: bundledPath)
        process?.arguments = ["-config", configPath]
        
        // Setup pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe
        
        // Handle output
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                self?.addLog(output)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                self?.addLog("⚠️ \(output)")
            }
        }
        
        // Handle termination
        process?.terminationHandler = { [weak self] process in
            // Clear pipe handlers to prevent memory leaks
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.activeConfigPath = ""
                self?.addLog("Server stopped with code: \(process.terminationStatus)")
                NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
            }
        }
        
        do {
            try process?.run()
            DispatchQueue.main.async {
                self.isRunning = true
                self.activeConfigPath = configPath
            }
            addLog("✓ Server started on port \(port)")
            
            // Wait a bit to ensure it started successfully
            DispatchQueue.main.asyncAfter(deadline: .now() + Timing.readinessCheckDelay) { [weak self] in
                guard let self = self else { return }
                if let process = self.process, process.isRunning {
                    NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
                    completion(true)
                } else {
                    self.addLog("⚠️ Server exited before becoming ready")
                    completion(false)
                }
            }
        } catch {
            addLog("❌ Failed to start server: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func stop(completion: (() -> Void)? = nil) {
        guard let process = process else {
            DispatchQueue.main.async {
                self.isRunning = false
                NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
                completion?()
            }
            return
        }
        
        let pid = process.processIdentifier
        addLog("Stopping server (PID: \(pid))...")
        processQueue.async { [weak self] in
            guard let self = self else { return }
            
            // First try graceful termination (SIGTERM)
            process.terminate()
            
            // Wait up to configured interval for graceful termination
            let deadline = Date().addingTimeInterval(Timing.gracefulTerminationTimeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: Timing.terminationPollInterval)
            }
            
            // If still running, force kill (SIGKILL)
            if process.isRunning {
                self.addLog("⚠️ Server didn't stop gracefully, force killing...")
                kill(pid, SIGKILL)
            }
            
            process.waitUntilExit()
            
            DispatchQueue.main.async {
                self.process = nil
                self.isRunning = false
                self.activeConfigPath = ""
                self.addLog("✓ Server stopped")
                NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
                completion?()
            }
        }
    }
    
    func runAuthCommand(_ command: AuthCommand, completion: @escaping (Bool, String) -> Void) {
        // Use bundled binary from app bundle
        guard let resourcePath = Bundle.main.resourcePath else {
            completion(false, "Could not find resource path")
            return
        }
        
        let bundledPath = (resourcePath as NSString).appendingPathComponent("cli-proxy-api-plus")
        guard FileManager.default.fileExists(atPath: bundledPath) else {
            completion(false, "Binary not found at \(bundledPath)")
            return
        }
        
        let authProcess = Process()
        authProcess.executableURL = URL(fileURLWithPath: bundledPath)
        
        let configPath = getConfigPath()
        guard !configPath.isEmpty else {
            completion(false, configErrorMessage ?? "Could not resolve config path")
            return
        }
        
        var qwenEmail: String?
        
        switch command {
        case .claudeLogin:
            authProcess.arguments = ["--config", configPath, "-claude-login"]
        case .codexLogin:
            authProcess.arguments = ["--config", configPath, "-codex-login"]
        case .copilotLogin:
            authProcess.arguments = ["--config", configPath, "-github-copilot-login"]
        case .geminiLogin:
            authProcess.arguments = ["--config", configPath, "-login"]
        case .qwenLogin(let email):
            authProcess.arguments = ["--config", configPath, "-qwen-login"]
            qwenEmail = email
        case .antigravityLogin:
            authProcess.arguments = ["--config", configPath, "-antigravity-login"]
        }
        
        // Create pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        authProcess.standardOutput = outputPipe
        authProcess.standardError = errorPipe
        authProcess.standardInput = inputPipe
        
        // For Copilot, we need to capture the device code from output
        let capture = OutputCapture()
        
        if case .copilotLogin = command {
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    capture.text += str
                    NSLog("[Auth] Copilot output: %@", str)
                }
            }
        }
        
        // For Gemini login, automatically send newline to accept default project
        if case .geminiLogin = command {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.0) {
                // Send newline after 3 seconds to accept default project choice
                if authProcess.isRunning {
                    if let data = "\n".data(using: .utf8) {
                        try? inputPipe.fileHandleForWriting.write(contentsOf: data)
                        NSLog("[Auth] Sent newline to accept default project")
                    }
                }
            }
        }

        // For Codex login, avoid blocking on the manual callback prompt after ~15s.
        if case .codexLogin = command {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 12.0) {
                // Send newline before the prompt to keep waiting for browser callback.
                if authProcess.isRunning {
                    if let data = "\n".data(using: .utf8) {
                        try? inputPipe.fileHandleForWriting.write(contentsOf: data)
                        NSLog("[Auth] Sent newline to keep Codex login waiting for callback")
                    }
                }
            }
        }
        
        // For Qwen login, automatically send email after OAuth completes
        // NOTE: 10 second delay chosen to ensure OAuth browser flow completes before submitting email.
        // This is a conservative estimate - OAuth typically completes in 5-8 seconds, but network
        // conditions and user interaction time can vary. Future improvement: monitor authProcess
        // output or termination handler to detect OAuth completion signal and submit immediately.
        if let email = qwenEmail {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 10.0) {
                // Send email after OAuth completion
                if authProcess.isRunning {
                    if let data = "\(email)\n".data(using: .utf8) {
                        try? inputPipe.fileHandleForWriting.write(contentsOf: data)
                        NSLog("[Auth] Sent Qwen email: %@", email)
                    }
                }
            }
        }
        
        // Set environment to inherit from parent
        authProcess.environment = ProcessInfo.processInfo.environment
        
        do {
            NSLog("[Auth] Starting process: %@ with args: %@", bundledPath, authProcess.arguments?.joined(separator: " ") ?? "none")
            try authProcess.run()
            addLog("✓ Authentication process started (PID: \(authProcess.processIdentifier)) - browser should open shortly")
            NSLog("[Auth] Process started with PID: %d", authProcess.processIdentifier)
            
            // Set up termination handler to detect when auth completes
            authProcess.terminationHandler = { process in
                let exitCode = process.terminationStatus
                NSLog("[Auth] Process terminated with exit code: %d", exitCode)
                
                if exitCode == 0 {
                    // Authentication completed successfully
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Give file system a moment to write the credential file
                        NotificationCenter.default.post(name: .authDirectoryChanged, object: nil)
                    }
                }
            }
            
            // Wait briefly to check if process crashes immediately or to capture output
            let waitTime: TimeInterval = (command == .copilotLogin) ? 2.0 : 1.0
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + waitTime) {
                if authProcess.isRunning {
                    // Process is still running - check for Copilot device code
                    NSLog("[Auth] Process running after wait, returning success")
                    
                    // For Copilot, try to extract the device code from output
                    if case .copilotLogin = command {
                        // Extract code from output like "enter the code: XXXX-XXXX"
                        if let codeRange = capture.text.range(of: "enter the code: "),
                           let endRange = capture.text[codeRange.upperBound...].range(of: "\n") {
                            let code = String(capture.text[codeRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                            // Copy code to clipboard
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(code, forType: .string)
                            completion(true, "🌐 Browser opened for GitHub authentication.\n\n📋 Code copied to clipboard:\n\n\(code)\n\nJust paste it in the browser!\n\nThe app will automatically detect when you're authenticated.")
                            return
                        } else if capture.text.contains("enter the code:") {
                            // Try simpler extraction
                            let lines = capture.text.components(separatedBy: "\n")
                            for line in lines {
                                if line.contains("enter the code:") {
                                    let parts = line.components(separatedBy: "enter the code:")
                                    if parts.count > 1 {
                                        let code = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                        // Copy code to clipboard
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(code, forType: .string)
                                        completion(true, "🌐 Browser opened for GitHub authentication.\n\n📋 Code copied to clipboard:\n\n\(code)\n\nJust paste it in the browser!\n\nThe app will automatically detect when you're authenticated.")
                                        return
                                    }
                                }
                            }
                        }
                        // Fallback if we couldn't extract the code
                        completion(true, "🌐 Browser opened for GitHub authentication.\n\nCheck your terminal or the opened browser for the device code.\n\nThe app will automatically detect when you're authenticated.")
                        return
                    }
                    
                    completion(true, "🌐 Browser opened for authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect when you're authenticated.")
                } else {
                    // Process died quickly - check for error
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    var output = String(data: outputData, encoding: .utf8) ?? ""
                    if output.isEmpty { output = capture.text }
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    NSLog("[Auth] Process died quickly - output: %@", output.isEmpty ? "(empty)" : String(output.prefix(200)))
                    
                    if output.contains("Opening browser") || output.contains("Attempting to open URL") {
                        // Browser opened but process finished (probably success)
                        NSLog("[Auth] Browser opened, process completed")
                        completion(true, "🌐 Browser opened for authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect when you're authenticated.")
                    } else {
                        // Real error
                        NSLog("[Auth] Process failed")
                        let message = error.isEmpty ? (output.isEmpty ? "Authentication process failed unexpectedly" : output) : error
                        completion(false, message)
                    }
                }
            }
        } catch {
            NSLog("[Auth] Failed to start: %@", error.localizedDescription)
            completion(false, "Failed to start auth process: \(error.localizedDescription)")
        }
    }
    
    private func addLog(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let logLine = "[\(timestamp)] \(message)"
            
            self.logBuffer.append(logLine)
            self.onLogUpdate?(self.logBuffer.elements())
        }
    }
    
    /// Saves a Z.AI API key to the auth directory
    func saveZaiApiKey(_ apiKey: String, completion: @escaping (Bool, String) -> Void) {
        let authDir = authDirectoryURL()
        
        do {
            try FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
        } catch {
            completion(false, "Failed to create auth directory: \(error.localizedDescription)")
            return
        }
        
        let keyPreview = maskAPIKey(apiKey)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "zai-\(UUID().uuidString.prefix(8)).json"
        let filePath = authDir.appendingPathComponent(filename)
        let authData: [String: Any] = [
            "type": "zai",
            "email": keyPreview,
            "api_key": apiKey,
            "created": timestamp
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: authData, options: .prettyPrinted)
            try jsonData.write(to: filePath)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: filePath.path)
            addLog("✓ Z.AI API key saved to \(filename)")
            reloadCustomProviders()
            applyConfigUpdate()
            completion(true, "API key saved successfully")
        } catch {
            completion(false, "Failed to save API key: \(error.localizedDescription)")
        }
    }
    
    func saveCustomProviderAPIKey(providerID: String, apiKey: String, completion: @escaping (Bool, String) -> Void) {
        let authDir = authDirectoryURL()
        
        do {
            try FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
        } catch {
            completion(false, "Failed to create auth directory: \(error.localizedDescription)")
            return
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "openai-compat-\(sanitizeFilenameComponent(providerID))-\(UUID().uuidString.prefix(8)).json"
        let filePath = authDir.appendingPathComponent(filename)
        let authData: [String: Any] = [
            "type": CustomProviderConstants.authType,
            "provider": providerID,
            "label": maskAPIKey(apiKey),
            "api_key": apiKey,
            "created": timestamp
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: authData, options: .prettyPrinted)
            try jsonData.write(to: filePath)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: filePath.path)
            addLog("✓ Saved API key for custom provider: \(providerID)")
            reloadCustomProviders()
            applyConfigUpdate()
            completion(true, "API key saved successfully")
        } catch {
            completion(false, "Failed to save API key: \(error.localizedDescription)")
        }
    }
    
    @discardableResult
    func deleteCustomProviderCredential(_ credential: CustomProviderCredential) -> Bool {
        do {
            try FileManager.default.removeItem(at: credential.filePath)
            addLog("✓ Removed custom provider key: \(credential.label)")
            reloadCustomProviders()
            applyConfigUpdate()
            return true
        } catch {
            NSLog("[ServerManager] Failed to delete custom provider credential: %@", error.localizedDescription)
            return false
        }
    }
    
    @discardableResult
    func toggleCustomProviderCredentialDisabled(_ credential: CustomProviderCredential) -> Bool {
        do {
            let data = try Data(contentsOf: credential.filePath)
            guard var json = ConfigComposer.stringKeyedDictionary(try JSONSerialization.jsonObject(with: data)) else {
                return false
            }
            
            let currentlyDisabled = json["disabled"] as? Bool ?? false
            json["disabled"] = !currentlyDisabled
            let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            try updatedData.write(to: credential.filePath, options: Data.WritingOptions.atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credential.filePath.path)
            reloadCustomProviders()
            applyConfigUpdate()
            return true
        } catch {
            NSLog("[ServerManager] Failed to toggle custom provider credential: %@", error.localizedDescription)
            return false
        }
    }
    
    func reloadCustomProviders() {
        switch loadBaseConfigRoot() {
        case .success(let config):
            clearConfigError()
            let providers = ConfigComposer.parseCustomProviders(
                from: config.root,
                reservedProviderIDs: Self.reservedCustomProviderKeys
            )
            let managedProviderIDs = Set(providers.map { $0.id })
            let credentials = Dictionary(
                grouping: loadCustomProviderAuthRecords().filter { managedProviderIDs.contains($0.providerID) },
                by: \.providerID
            ).mapValues { records in
                records
                    .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
                    .map {
                        CustomProviderCredential(
                            id: $0.filePath.lastPathComponent,
                            providerID: $0.providerID,
                            label: $0.label,
                            filePath: $0.filePath,
                            isDisabled: $0.isDisabled
                        )
                    }
            }

            DispatchQueue.main.async {
                self.customProviders = providers
                self.customProviderCredentials = credentials
            }
        case .failure(let error):
            publishConfigError(error.message)
            DispatchQueue.main.async {
                self.customProviders = []
                self.customProviderCredentials = [:]
            }
        }
    }
    
    /// Returns the config path to use, merging the base config with provider state and API-key auth files.
    func getConfigPath() -> String {
        switch resolveConfigPath() {
        case .success(let path):
            clearConfigError()
            return path
        case .failure(let error):
            publishConfigError(error.message)
            return ""
        }
    }

    private func resolveConfigPath() -> Result<String, ConfigResolutionFailure> {
        guard let bundledConfigPath = bundledConfigPath() else {
            return .failure(ConfigResolutionFailure(message: "Could not locate the bundled config.yaml in the app bundle."))
        }
        let baseConfigResult = loadBaseConfigRoot()
        guard case .success(let baseConfig) = baseConfigResult else {
            if case .failure(let error) = baseConfigResult {
                return .failure(error)
            }
            return .failure(ConfigResolutionFailure(message: "Could not load the base configuration."))
        }
        
        let authDir = authDirectoryURL()
        let zaiApiKeys = loadZaiAPIKeys()
        let customAuthRecords = loadCustomProviderAuthRecords()
        let managedCustomProviders = ConfigComposer.parseCustomProviders(
            from: baseConfig.root,
            reservedProviderIDs: Self.reservedCustomProviderKeys
        )
        let disabledProviders = Self.oauthProviderKeys.compactMap { serviceKey, oauthKey in
            isProviderEnabled(serviceKey) ? nil : oauthKey
        }
        let disabledCustomProviderIDs = Set(managedCustomProviders.map { $0.id }).filter { !isProviderEnabled($0) }
        let needsMergedConfig =
            baseConfig.isUserConfig ||
            !zaiApiKeys.isEmpty ||
            !disabledProviders.isEmpty ||
            !disabledCustomProviderIDs.isEmpty ||
            !customAuthRecords.isEmpty
        
        guard needsMergedConfig else {
            return .success(bundledConfigPath)
        }
        
        let mergedRoot = ConfigComposer.composeRuntimeConfig(
            baseRoot: baseConfig.root,
            reservedCustomProviderKeys: Self.reservedCustomProviderKeys,
            disabledCustomProviderIDs: disabledCustomProviderIDs,
            disabledOAuthProviderKeys: disabledProviders,
            zaiAPIKeys: zaiApiKeys,
            customProviderAuthRecords: customAuthRecords.map {
                ConfigProviderAuthRecord(
                    providerID: $0.providerID,
                    apiKey: $0.apiKey,
                    isDisabled: $0.isDisabled
                )
            },
            includeManagedZAIProvider: isProviderEnabled(CustomProviderConstants.managedZAIProviderName),
            managedZAIProviderName: CustomProviderConstants.managedZAIProviderName
        )
        
        let mergedConfigPath = authDir.appendingPathComponent(CustomProviderConstants.mergedConfigFilename)
        do {
            try FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
            let mergedContent = try Yams.dump(object: mergedRoot)
            try mergedContent.write(to: mergedConfigPath, atomically: true, encoding: String.Encoding.utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: mergedConfigPath.path)
            return .success(mergedConfigPath.path)
        } catch {
            return .failure(
                ConfigResolutionFailure(
                    message: "Failed to write merged config to \(mergedConfigPath.path): \(error.localizedDescription)"
                )
            )
        }
    }
    
    func getLogs() -> [String] {
        return logBuffer.elements()
    }
    
    /// Kill any orphaned cli-proxy-api-plus processes that might be running
    private func killOrphanedProcesses() {
        // First check if any processes exist using pgrep
        let checkTask = Process()
        checkTask.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        checkTask.arguments = ["-f", "cli-proxy-api-plus"]
        
        let outputPipe = Pipe()
        checkTask.standardOutput = outputPipe
        checkTask.standardError = Pipe() // Suppress errors
        
        do {
            try checkTask.run()
            checkTask.waitUntilExit()
            
            // If pgrep found processes (exit code 0), kill them
            if checkTask.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let pids = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                
                if !pids.isEmpty {
                    addLog("⚠️ Found orphaned server process(es): \(pids.joined(separator: ", "))")
                    
                    // Now kill them
                    let killTask = Process()
                    killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
                    killTask.arguments = ["-9", "-f", "cli-proxy-api-plus"]
                    
                    try killTask.run()
                    killTask.waitUntilExit()
                    
                    // Wait a moment for cleanup
                    Thread.sleep(forTimeInterval: 0.5)
                    addLog("✓ Cleaned up orphaned processes")
                }
            }
            // Exit code 1 means no processes found - this is fine, no need to log
        } catch {
            // Silently fail - this is not critical
        }
    }
    
    private func bundledConfigPath() -> String? {
        guard let resourcePath = Bundle.main.resourcePath else {
            return nil
        }
        return (resourcePath as NSString).appendingPathComponent("config.yaml")
    }
    
    private func authDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
    }
    
    private func loadBaseConfigRoot() -> Result<LoadedBaseConfig, ConfigResolutionFailure> {
        guard let bundledConfigPath = bundledConfigPath() else {
            return .failure(ConfigResolutionFailure(message: "Could not locate the bundled config.yaml in the app bundle."))
        }
        let bundledRootResult = loadYAMLDictionary(atPath: bundledConfigPath)
        guard case .success(let bundledRoot) = bundledRootResult else {
            if case .failure(let error) = bundledRootResult {
                return .failure(error)
            }
            return .failure(ConfigResolutionFailure(message: "Could not load the bundled config at \(bundledConfigPath)."))
        }
        
        let userConfigPath = authDirectoryURL()
            .appendingPathComponent(CustomProviderConstants.userConfigFilename)
            .path
        guard FileManager.default.fileExists(atPath: userConfigPath) else {
            return .success(LoadedBaseConfig(root: bundledRoot, isUserConfig: false))
        }
        
        let userRootResult = loadYAMLDictionary(atPath: userConfigPath)
        guard case .success(let userRoot) = userRootResult else {
            if case .failure(let error) = userRootResult {
                return .failure(error)
            }
            return .failure(ConfigResolutionFailure(message: "Could not load the user config at \(userConfigPath)."))
        }
        
        return .success(
            LoadedBaseConfig(
                root: ConfigComposer.composeAdditiveBaseConfig(
                bundledRoot: bundledRoot,
                userRoot: userRoot
            ),
                isUserConfig: true
            )
        )
    }
    
    private func loadYAMLDictionary(atPath path: String) -> Result<[String: Any], ConfigResolutionFailure> {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            guard let loaded = try Yams.load(yaml: content) else {
                return .success([:])
            }
            guard let dictionary = ConfigComposer.stringKeyedDictionary(loaded) else {
                return .failure(ConfigResolutionFailure(message: "Config at \(path) must be a YAML mapping at the root."))
            }
            return .success(dictionary)
        } catch {
            return .failure(ConfigResolutionFailure(message: "Failed to parse YAML at \(path): \(error.localizedDescription)"))
        }
    }
    
    private func loadZaiAPIKeys() -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: authDirectoryURL(), includingPropertiesForKeys: nil) else {
            return []
        }
        return files.compactMap { file in
            guard file.lastPathComponent.hasPrefix("zai-"),
                  file.pathExtension == "json",
                  let json = readJSONFile(at: file),
                  let apiKey = json["api_key"] as? String else {
                return nil
            }
            return apiKey
        }
    }
    
    private func loadCustomProviderAuthRecords() -> [StoredCustomProviderAuthRecord] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: authDirectoryURL(), includingPropertiesForKeys: nil) else {
            return []
        }
        
        return files.compactMap { file in
            guard file.pathExtension == "json",
                  let json = readJSONFile(at: file),
                  (json["type"] as? String) == CustomProviderConstants.authType,
                  let providerID = json["provider"] as? String,
                  !providerID.isEmpty,
                  let apiKey = json["api_key"] as? String else {
                return nil
            }
            
            return StoredCustomProviderAuthRecord(
                providerID: providerID,
                apiKey: apiKey,
                label: (json["label"] as? String) ?? maskAPIKey(apiKey),
                filePath: file,
                isDisabled: json["disabled"] as? Bool ?? false
            )
        }
    }
    
    private func readJSONFile(at file: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: file),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return ConfigComposer.stringKeyedDictionary(jsonObject)
    }
    
    private func maskAPIKey(_ apiKey: String) -> String {
        guard apiKey.count > 12 else {
            return apiKey
        }
        return String(apiKey.prefix(8)) + "..." + String(apiKey.suffix(4))
    }
    
    private func sanitizeFilenameComponent(_ value: String) -> String {
        let sanitized = value.replacingOccurrences(
            of: "[^A-Za-z0-9._-]+",
            with: "-",
            options: .regularExpression
        )
        return sanitized.isEmpty ? "provider" : sanitized
    }

    private func publishConfigError(_ message: String) {
        let update = {
            let shouldLog = self.configErrorMessage != message
            self.configErrorMessage = message
            if shouldLog {
                self.addLog("❌ \(message)")
            }
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func clearConfigError() {
        let update = {
            self.configErrorMessage = nil
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }
    
    private func applyConfigUpdate() {
        guard !isRestartingForConfigUpdate else {
            hasPendingConfigUpdate = true
            return
        }
        
        let configPath = getConfigPath()
        guard !configPath.isEmpty else {
            return
        }
        
        let shouldRestart = isRunning && !activeConfigPath.isEmpty && activeConfigPath != configPath
        if shouldRestart {
            isRestartingForConfigUpdate = true
            hasPendingConfigUpdate = false
            addLog("Config path changed; restarting server")
            stop { [weak self] in
                self?.start { [weak self] _ in
                    self?.finishConfigUpdateRestart()
                }
            }
            return
        }
        
        if isRunning {
            addLog("Config updated (hot reload)")
        }
    }
    
    private func finishConfigUpdateRestart() {
        isRestartingForConfigUpdate = false
        guard hasPendingConfigUpdate else {
            return
        }
        hasPendingConfigUpdate = false
        applyConfigUpdate()
    }
}

enum AuthCommand: Equatable {
    case claudeLogin
    case codexLogin
    case copilotLogin
    case geminiLogin
    case qwenLogin(email: String)
    case antigravityLogin
}
