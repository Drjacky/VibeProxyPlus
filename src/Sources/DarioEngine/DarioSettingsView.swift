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
}

/// The Dario engine's settings surface (Split A).
///
/// Presents connection status, the local endpoint, account/backends summary, and a live log view.
/// Routing/DNS/profiles/import-export screens are stubbed with "managed by Dario" notes until the
/// real host (Split B) exposes the corresponding data from `~/.dario/config.json` and the proxy
/// endpoints. Built natively in the DarioEngine module - no shared view models with CLIProxy.
struct DarioSettingsView: View {
    @StateObject private var model: DarioSettingsModel
    @State private var isLoggingIn = false
    @State private var showingLoginResult = false
    @State private var loginResultMessage = ""

    init(host: DarioHost) {
        _model = StateObject(wrappedValue: DarioSettingsModel(host: host))
    }

    private func startLogin() {
        isLoggingIn = true
        model.login { _, message in
            self.isLoggingIn = false
            self.loginResultMessage = message
            self.showingLoginResult = true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
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

                Section("Claude account") {
                    HStack {
                        Text("Login")
                        Spacer()
                        Text(model.status.isLoggedIn ? "Logged in" : "Not logged in")
                            .foregroundColor(model.status.isLoggedIn ? .green : .secondary)
                        if isLoggingIn {
                            ProgressView().controlSize(.small)
                        } else {
                            Button(model.status.isLoggedIn ? "Re-login" : "Login") {
                                startLogin()
                            }
                            .controlSize(.small)
                        }
                    }
                    Text("Login opens your browser to authenticate your Claude subscription. The proxy will not serve requests until you are logged in.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Backends") {
                    if model.status.backends.isEmpty {
                        Text("No OpenAI-compatible backends configured.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(model.status.backends, id: \.self) { backend in
                            Text(backend)
                        }
                    }
                }

                Section("Routing, DNS, and networking") {
                    Text("These are application-level proxy settings owned by Dario (config.json under ~/.dario). The native editor is under construction.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

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
                                }
                            }
                        }
                        .frame(height: 160)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 740)
        .alert("Dario Login", isPresented: $showingLoginResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(loginResultMessage)
        }
    }

    private var statusColor: Color {
        switch model.status.state {
        case .running: return .green
        case .starting: return .orange
        case .stopped: return .red
        case .failed: return .red
        }
    }

    private var statusText: String {
        switch model.status.state {
        case .running: return "Running"
        case .starting: return "Starting..."
        case .stopped: return "Stopped"
        case .failed(let message): return "Failed: \(message)"
        }
    }
}

