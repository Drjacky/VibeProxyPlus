// CLIProxyEngine
//
// Fully isolated implementation of the cliproxyapiplus engine. The existing
// ServerManager/ThinkingProxy/TunnelManager/config/stores/SettingsView code migrates
// into this module in Phase 2 behind the EngineKit contracts.
//
// ISOLATION INVARIANT: this module must NEVER import DarioEngine.
//
// Depends on EngineKit, Persistence, ProcessRuntime, Diagnostics, SharedUI.

import Foundation
import EngineKit

/// Marker namespace for the CLIProxyEngine module.
public enum CLIProxyEngine {}

