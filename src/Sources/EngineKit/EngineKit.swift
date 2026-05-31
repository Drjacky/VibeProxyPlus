// EngineKit
//
// Shared engine contracts and lifecycle abstractions. Depends on Foundation only.
// This module must never import any concrete engine module (CLIProxyEngine, DarioEngine).
//
// Populated in later phases (see plans/dario-integration-architecture.md, Part A/B).

import Foundation

/// Marker namespace for the EngineKit module.
///
/// Phase 0 introduces the module boundary only; contracts (`Engine`, `EngineHost`,
/// `EngineDescriptor`, `EngineCapabilities`, `EngineContext`, etc.) are added in later phases.
public enum EngineKit {
    /// Semantic version of the engine-contract surface. Bumped when contracts change.
    public static let contractVersion = "0.0.0"
}
