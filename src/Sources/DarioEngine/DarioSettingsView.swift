import SwiftUI

/// Observable view model bridging a `DarioHost` to the Dario settings UI.
@MainActor
final class DarioSettingsModel: ObservableObject {
    @Published private(set) var status: DarioStatusSnapshot
    @Published private(set) var logLines: [String]

    private let host: DarioHost

    init(host: DarioHost) {
        self.host = host
        self.status = host.status
        self.logLines = host.recentLogLines()
        // Subscribe after capturing initial state.
        let existing = host.onStatusChange
        host.onStatusChange = { [weak self] in
            existing?()
            self?.refresh()
        }
    }

    var savedAPIBaseURL: String? { host.savedAPIBaseURL }

    func refresh() {
        status = host.status
        logLines = host.recentLogLines()
    }

    func toggleRunning() {
        if status.state.isRunning {
            host.stop { [weak self] in self?.refresh() }
        } else {
            host.start { [weak self] _ in self?.refresh() }
        }
    }

    func login(completion: @escaping (Bool, String) -> Void) {
        host.login { [weak self] success, message in
            self?.refresh()
            completion(success, message)
        }
    }

    func setAPIKey(baseURL: String, apiKey: String, completion: @escaping (Bool, String) -> Void) {
        host.setAPIKey(baseURL: baseURL, apiKey: apiKey) { [weak self] success, message in
            self?.refresh()
            completion(success, message)
        }
    }

    func setAPIKeyEnabled(_ enabled: Bool, completion: @escaping (Bool, String) -> Void) {
        host.setAPIKeyEnabled(enabled) { [weak self] success, message in
            self?.refresh()
            completion(success, message)
        }
    }
}

/// The Dario engine's settings surface.
///
/// Presents connection status, the local endpoint, two authentication options (subscription OAuth
/// and API key + base URL with an enable toggle), and a live log view. Built natively in the
/// DarioEngine module - no shared view models with CLIProxy.
struct DarioSettingsView: View {
    @StateObject private var model: DarioSettingsModel
    @State private var isWorking = false
    @State private var showingLoginResult = false
    @State private var loginResultMessage = ""
    @State private var showingAPIKeySheet = false
    @State private var apiBaseURL = ""
    @State private var apiKey = ""

    init(host: DarioHost) {
        _model = StateObject(wrappedValue: DarioSettingsModel(host: host))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                statusSection
                claudeAccountSection
                backendsSection
                routingSection
                logsSection
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 760)
        .alert("Dario", isPresented: $showingLoginResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(loginResultMessage)
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            apiKeySheet
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack {
                Text("Proxy status")
                Spacer()
                Button(action: { model.toggleRunning() }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                    }
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("Local endpoint")
                Spacer()
                Text(model.status.endpoint.absoluteString)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var claudeAccountSection: some View {
        Section("Claude account") {
            HStack {
                Text("Authentication")
                Spacer()
                Text(authSummary)
                    .foregroundColor(authSummaryColor)
                if isWorking {
                    ProgressView().controlSize(.small)
                }
            }

            // Subscription (OAuth) - the stealth path.
            HStack {
                Text("Subscription (OAuth)")
                Spacer()
                Button(model.status.isSubscriptionLoggedIn ? "Re-login" : "Login") {
                    startLogin()
                }
                .controlSize(.small)
                .disabled(isWorking)
            }
            Text("Opens your browser to authenticate a Claude Pro/Max subscription. Uses Dario's full Claude-Code stealth/fingerprint on the upstream request.")
                .font(.caption)
                .foregroundColor(.secondary)

            // API key + base URL - the plain passthrough path, with an enable toggle.
            HStack {
                Text("API key + base URL")
                Spacer()
                Button(model.status.apiKeyConfigured ? "Edit API key..." : "Set API key...") {
                    apiBaseURL = model.savedAPIBaseURL ?? ""
                    apiKey = ""
                    showingAPIKeySheet = true
                }
                .controlSize(.small)
                .disabled(isWorking)
            }

            Toggle(isOn: apiKeyToggleBinding) {
                Text("Use API key")
            }
            .disabled(isWorking || !model.status.apiKeyConfigured)

            Text("Use a custom base URL and API key (no subscription needed). When enabled, requests route through Dario's OpenAI-compatible passthrough, which does NOT apply the Claude-Code stealth/fingerprint.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var backendsSection: some View {
        Section("Backends") {
            if model.status.backends.isEmpty {
                Text("No API backend active.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(model.status.backends, id: \.self) { backend in
                    Text(backend)
                }
            }
        }
    }

    private var routingSection: some View {
        Section("Routing, DNS, and networking") {
            Text("These are application-level proxy settings owned by Dario (config.json under ~/.dario). The native editor is under construction.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var logsSection: some View {
        Section("Logs") {
            if model.logLines.isEmpty {
                Text("No log output yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(model.logLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(height: 160)
                Button("Copy all logs") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(model.logLines.joined(separator: "\n"), forType: .string)
                }
                .controlSize(.small)
            }
        }
    }

    private var apiKeySheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.status.apiKeyConfigured ? "Edit API key" : "Set API key")
                .font(.headline)
            Text("Configure a custom Claude-compatible endpoint. This does not require a subscription and does not use Claude-Code stealth.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Base URL")
                    .font(.caption)
                TextField("https://api.example.com/v1", text: $apiBaseURL)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("API key")
                    .font(.caption)
                SecureField(model.status.apiKeyConfigured ? "Leave blank to keep current key" : "sk-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                if model.status.apiKeyConfigured {
                    Text("A key is already saved (hidden for security). Leave this blank to keep it, or type a new key to replace it.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    showingAPIKeySheet = false
                    apiKey = ""
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    saveAPIKey()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSaveAPIKey)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    /// Save is allowed when a base URL is present and either a new key was typed or a key is
    /// already saved (so editing just the base URL is possible without re-entering the secret).
    private var canSaveAPIKey: Bool {
        let urlFilled = !apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let keyTyped = !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return urlFilled && (keyTyped || model.status.apiKeyConfigured)
    }

    // MARK: - Actions

    private func startLogin() {
        isWorking = true
        model.login { _, message in
            self.isWorking = false
            self.loginResultMessage = message
            self.showingLoginResult = true
        }
    }

    private func saveAPIKey() {
        showingAPIKeySheet = false
        isWorking = true
        model.setAPIKey(baseURL: apiBaseURL, apiKey: apiKey) { _, message in
            self.isWorking = false
            self.apiKey = ""
            self.loginResultMessage = message
            self.showingLoginResult = true
        }
    }

    private var apiKeyToggleBinding: Binding<Bool> {
        Binding(
            get: { model.status.apiKeyEnabled },
            set: { newValue in
                isWorking = true
                model.setAPIKeyEnabled(newValue) { success, message in
                    self.isWorking = false
                    if !success {
                        self.loginResultMessage = message
                        self.showingLoginResult = true
                    }
                }
            }
        )
    }

    // MARK: - Derived display state

    /// Whether any usable upstream is configured (subscription logged in, or API key enabled).
    private var isAuthenticated: Bool {
        model.status.isSubscriptionLoggedIn || model.status.apiKeyEnabled
    }

    private var authSummary: String {
        if model.status.isSubscriptionLoggedIn && model.status.apiKeyEnabled {
            return "Subscription + API key"
        }
        if model.status.isSubscriptionLoggedIn {
            return "Subscription (stealth)"
        }
        if model.status.apiKeyEnabled {
            return "API key (no stealth)"
        }
        if model.status.apiKeyConfigured {
            return "API key saved (disabled)"
        }
        return "Not authenticated"
    }

    private var authSummaryColor: Color {
        if model.status.isSubscriptionLoggedIn { return .green }
        if model.status.apiKeyEnabled { return .orange }
        return .secondary
    }

    /// Status dot color encodes both run + auth state:
    /// - green: subscription logged in (stealth available)
    /// - yellow: not logged in but API key is enabled (works, no stealth)
    /// - red: neither - the proxy cannot authenticate
    /// While starting, show orange.
    private var statusColor: Color {
        switch model.status.state {
        case .starting:
            return .orange
        default:
            if model.status.isSubscriptionLoggedIn { return .green }
            if model.status.apiKeyEnabled { return .yellow }
            return .red
        }
    }

    private var statusText: String {
        switch model.status.state {
        case .running:
            if model.status.isSubscriptionLoggedIn { return "Running (subscription)" }
            if model.status.apiKeyEnabled { return "Running (API key)" }
            return "Running"
        case .starting:
            return "Starting..."
        case .stopped:
            if model.status.isSubscriptionLoggedIn { return "Stopped (subscription ready)" }
            if model.status.apiKeyEnabled { return "Stopped (API key ready)" }
            return "Stopped (not authenticated)"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }
}
