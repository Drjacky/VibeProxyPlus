// CLIProxyEngine
//
// Isolated implementation of the cliproxyapiplus engine: ServerManager, ThinkingProxy,
// TunnelManager, config composition, credential stores, and the settings UI, exposed to the
// shell through the EngineKit contracts.
//
// ISOLATION INVARIANT: this module must NEVER import DarioEngine.
//
// Depends on EngineKit, Persistence, ProcessRuntime, Diagnostics, SharedUI.

import Foundation
import EngineKit

/// Marker namespace for the CLIProxyEngine module.
public enum CLIProxyEngine {}

